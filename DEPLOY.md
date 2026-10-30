# 배포 가이드 (Fly.io + Vercel, 무료 티어)

이 문서대로 진행하면 **누구나 접속할 수 있는 공개 URL** 이 생깁니다.
순서는 **백엔드(Fly.io) → 웹(Vercel)** 이에요. 백엔드 URL이 정해져야 웹에서 가리킬 수 있어서.

## 0. 사전 준비

- **Fly.io 계정**: <https://fly.io/app/sign-up> (GitHub 로그인 가능, 무료)
  - 신용카드 등록 요구하는 경우 있음 (free credit $5 안에서만 쓰면 청구 안 됨)
- **Vercel 계정**: <https://vercel.com/signup> (GitHub 로그인, 무료)
- **flyctl CLI**: <https://fly.io/docs/flyctl/install/>
  - Windows PowerShell: `iwr https://fly.io/install.ps1 -useb | iex`
- **Vercel CLI**: `npm i -g vercel`

설치 확인:
```powershell
flyctl version
vercel --version
```

---

## 1. 백엔드 배포 (Fly.io)

### 1-1. Fly 로그인

```powershell
flyctl auth login
```
브라우저 창이 떠서 로그인 → 토큰 자동 발급.

### 1-2. Fly 앱 생성 + 첫 배포

`backend/fly.toml` 의 `app = "chatgame-backend"` 가 전 세계에서 유일해야 해요. **본인만의 이름으로 바꾸세요** (예: `sangbae-api`, `quiz-sangbae-be` 등).

`backend/fly.toml` 에서 `app = "여기-바꿔주세요"` 수정.

그리고:

```powershell
cd backend
flyctl launch --no-deploy --copy-config
```
- 대화형 질문이 떠요. 대부분 기본값 OK.
- "Would you like to deploy now?" → **No** (DB 만든 다음에 배포해야 함)

### 1-3. Postgres 생성 + 연결

```powershell
flyctl postgres create --name 여러분의앱이름-pg --region nrt --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 1
flyctl postgres attach 여러분의앱이름-pg --app 여러분의앱이름
```
두 번째 명령이 `DATABASE_URL` 시크릿을 자동으로 앱에 주입합니다 (백엔드 코드가 `postgres://` → `postgresql+asyncpg://` 로 변환해서 사용).

### 1-4. Redis 생성

Fly Redis는 Upstash 가 제공해요. 무료 티어 충분.

```powershell
flyctl redis create
```
- 이름/지역 묻는 질문에 적당히 답하면 됩니다.
- 출력 마지막에 `REDIS_URL=...` 가 뜨면 복사해두세요.

이미 attach가 안 됐다면:
```powershell
flyctl secrets set REDIS_URL="복사한주소" --app 여러분의앱이름
```

### 1-5. 나머지 시크릿 + CORS

```powershell
# 안전한 랜덤 SECRET_KEY 생성 (PowerShell)
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$key = [Convert]::ToBase64String($bytes)
flyctl secrets set SECRET_KEY=$key --app 여러분의앱이름

# CORS: Vercel 도메인을 곧 알게 되니 일단 전부 허용으로 시작했다가 좁히세요.
flyctl secrets set CORS_ORIGINS="https://sangbae.vercel.app,http://localhost:5173" --app 여러분의앱이름
```

### 1-6. 배포

```powershell
flyctl deploy --app 여러분의앱이름
```
- 빌드 + 푸시 (1~3분)
- `release_command` 가 자동으로 `alembic upgrade head` + 문제 동기화(`scripts.sync_questions`) 실행
  (`app/questions/seed_data.py` 의 401문항이 DB와 같아지도록 추가·수정·삭제. 문제를 고치고 다시 배포하면 반영됨)
- 헬스체크 통과 후 traffic 스위치

배포 끝나면 도메인이 나옵니다: `https://여러분의앱이름.fly.dev`. 

```powershell
curl https://여러분의앱이름.fly.dev/healthz
# {"status":"ok"}
curl https://여러분의앱이름.fly.dev/questions/count
# {"count":401}
```

---

## 2. 웹 배포 (Vercel)

### 2-1. vercel.json 의 백엔드 주소 수정

`web/vercel.json` 열어서 `chatgame-backend.fly.dev` 부분을 본인의 Fly URL로 바꿔주세요:

```json
"destination": "https://여러분의앱이름.fly.dev/:path*"
```

### 2-2. 환경변수 (WebSocket 베이스)

Vercel은 WebSocket을 rewrite 못 해요. 그래서 클라이언트가 Fly에 직접 붙도록 환경변수를 줘야 합니다.

```powershell
cd ..\web
vercel login
```
브라우저 로그인 후:

```powershell
# 프로젝트 첫 연결 (대화형). Framework Preset = Vite 자동 인식.
vercel link

# 프로덕션용 환경변수 (값을 묻습니다 — 본인 Fly URL을 wss:// 로 입력)
vercel env add VITE_WS_BASE production
# 입력값: wss://여러분의앱이름.fly.dev
```

### 2-3. 첫 배포

```powershell
vercel --prod
```
1~2분 후 도메인이 나옵니다: `https://여러분의프로젝트.vercel.app`.

### 2-4. CORS 확정 (역참조)

이제 진짜 Vercel 도메인을 알았으니 Fly 측 CORS에 박아넣고 좁혀줍니다:

```powershell
flyctl secrets set CORS_ORIGINS="https://여러분의프로젝트.vercel.app" --app 여러분의앱이름
```
(시크릿 변경하면 자동 재배포 한 번 일어남)

### 2-5. 동작 확인

브라우저: `https://여러분의프로젝트.vercel.app`
- 닉네임 입력 → 방 만들기 → 방코드 표시
- 시크릿창에서 같은 코드로 입장 → 게임 시작 → 정답 → 점수 → 결과

✅ 끝.

---

## 3. SEO 마무리 손질 (선택, 5분)

배포된 도메인을 메타 태그/사이트맵에 정확히 박아주세요:

- `web/index.html`: `og:url`, `canonical` 의 `sangbae.vercel.app` → 본인 도메인으로
- `web/public/sitemap.xml`: `<loc>` 도메인 변경
- `web/public/robots.txt`: 마지막 `Sitemap:` 줄 도메인 변경

수정 후:
```powershell
vercel --prod
```

### Google Search Console 등록 (선택)

<https://search.google.com/search-console> 접속 → "URL 접두어" → 본인 Vercel 도메인 입력 → 소유권 확인 (HTML 태그 방식 권장: index.html `<head>` 에 한 줄 추가 → 재배포) → 사이트맵 제출 (`https://여러분의도메인/sitemap.xml`).

며칠~몇 주 후 "상식배틀" 같은 본인 브랜드명 검색 시 노출 시작.

---

## 4. 자주 막히는 곳

**`flyctl deploy` 가 release_command 단계에서 멈춤**
- 보통 DB 연결 문제. `flyctl secrets list` 로 `DATABASE_URL` 있는지 확인.
- 로그: `flyctl logs --app 여러분의앱이름`

**브라우저에서 게임 시작했는데 채팅이 안 됨**
- DevTools Network 탭에서 WebSocket 연결 보세요. 빨간색이면 `VITE_WS_BASE` 미설정 또는 Fly CORS/허용 origin 문제.
- `flyctl logs` 에 `CORS` 에러 뜨는지 확인.

**Vercel에서 새로고침하면 404**
- `vercel.json` 의 SPA fallback 룰이 안 먹은 거예요. 파일이 `web/vercel.json` 에 있고 배포 시 포함됐는지 확인.

**Fly Postgres 가 잠시 후 잠들어 첫 요청이 느림**
- Fly Postgres 무료 티어 자동 일시정지 동작. 첫 요청 5~10초 걸릴 수 있어요. 이후 정상.

---

## 5. 비용 예상

- **Fly.io**: shared-cpu-1x VM 1대 (24/7) + Postgres 무료 1GB + Upstash Redis 무료 = $0/월
  - 진짜 0원이 되려면 청구서 확인 한 번 권장 (보통 트래픽 폭주 전엔 안전)
- **Vercel**: Hobby 플랜 100GB 대역폭/월, 정적 사이트라 사실상 무제한 = $0/월

월 활성 유저 100~1000명 수준까진 무료티어로 충분합니다.
