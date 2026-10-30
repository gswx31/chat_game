import { toast } from "../components/feedback";

export function inviteUrl(code: string): string {
  return `${location.origin}/j/${code}`;
}

export function inviteText(code: string): string {
  return `상식퀴즈배틀 같이 해요! 방 코드 ${code}`;
}

/** Copy text; works on iOS Safari and on plain-http pages (falls back to execCommand). */
export async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    /* fall through to the legacy path */
  }
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.cssText = "position:fixed;top:0;left:0;opacity:0;font-size:16px";
    document.body.appendChild(ta);
    ta.select();
    ta.setSelectionRange(0, text.length);
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

/** "코드 복사" */
export async function copyCode(code: string): Promise<void> {
  const ok = await copyText(code);
  toast(ok ? "방 코드를 복사했어요" : "복사하지 못했어요. 코드를 직접 알려주세요", ok ? "ok" : "error");
}

/**
 * "초대 링크 공유": opens the phone's share sheet (KakaoTalk / Messages …) when the browser
 * supports it, otherwise copies "text + link" to the clipboard.
 */
export async function shareInvite(code: string): Promise<void> {
  const url = inviteUrl(code);
  const text = inviteText(code);
  if (typeof navigator.share === "function") {
    try {
      await navigator.share({ title: "상식퀴즈배틀", text, url });
      return;
    } catch (e) {
      if ((e as DOMException)?.name === "AbortError") return; // user closed the sheet
      // any other failure: fall back to copying
    }
  }
  const ok = await copyText(`${text}\n${url}`);
  toast(ok ? "링크를 복사했어요" : "복사하지 못했어요. 코드를 직접 알려주세요", ok ? "ok" : "error");
}
