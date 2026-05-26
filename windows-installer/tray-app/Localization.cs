using System.Collections.Generic;
using System.Globalization;

namespace N8nTray
{
    /// Tiny key->string lookup. We avoid .resx to keep the build toolchain minimal —
    /// resx requires resgen and satellite assemblies which complicate the Inno Setup
    /// payload. Strings live here as a flat dictionary instead.
    internal static class Localization
    {
        private static readonly Dictionary<string, string> Ko = new Dictionary<string, string>
        {
            { "Menu.Open",          "n8n 열기" },
            { "Menu.Start",         "n8n 시작" },
            { "Menu.Stop",          "n8n 중지" },
            { "Menu.Restart",       "n8n 재시작" },
            { "Menu.Logs",          "로그 보기" },
            { "Menu.CopyUrl",       "URL 복사" },
            { "Menu.Update",        "n8n 업데이트" },
            { "Menu.DataFolder",    "데이터 폴더 열기" },
            { "Menu.AutoStart",     "Windows 시작 시 자동 실행" },
            { "Menu.About",         "정보" },
            { "Menu.Exit",          "종료" },
            { "Status.Idle",        "n8n: 중지됨" },
            { "Status.Starting",    "n8n: 시작 중…" },
            { "Status.Installing",  "n8n 본체 다운로드 중… 콘솔 창에서 진행 상황 확인" },
            { "Status.Running",     "n8n: 실행 중 — {0}" },
            { "Status.Stopping",    "n8n: 중지 중…" },
            { "Status.Error",       "n8n: 오류 발생 — 로그를 확인하세요" },
            { "Dialog.InstallTitle","n8n 처음 설치" },
            { "Dialog.InstallBody", "n8n 본체를 처음 다운로드합니다. 인터넷 연결이 필요합니다.\n\n별도의 콘솔 창이 열리며 npm 진행 상황이 실시간으로 표시됩니다.\n보통 5~15분 소요되며, 회선이 느리거나 사내 프록시 환경에서는 더 오래 걸릴 수 있습니다." },
            { "Dialog.UpdateTitle", "n8n 업데이트" },
            { "Dialog.UpdateBody",  "최신 n8n 버전을 받아옵니다. 잠시만 기다려 주세요." },
            { "Dialog.InstallFail", "n8n 설치에 실패했습니다.\n\n자세한 내용은 로그를 확인해 주세요.\n\n오류:\n{0}" },
            { "Dialog.UpdateFail",  "n8n 업데이트에 실패했습니다.\n\n{0}" },
            { "Dialog.AboutBody",   "n8n Tray Launcher\n버전 {0}\n\nn8n: {1}\n\n공식: https://n8n.io\n매뉴얼: https://docs.n8n.io" },
            { "Error.NodeMissing",  "Node.js 번들을 찾을 수 없습니다.\n인스톨러를 다시 실행해 주세요." },
            { "Balloon.Ready",        "n8n 실행 중\n{0}\n트레이 아이콘 좌클릭으로 언제든 열기" },
            { "Balloon.ReadyShifted", "n8n 실행 중\n{0}\n\n(기본 포트 5678이 다른 프로그램에 사용 중이라 {1}번 포트로 자동 변경됨. 트레이 아이콘 좌클릭이 가장 안전)" },
            { "Balloon.UrlCopied",    "URL 복사됨: {0}" },
        };

        private static readonly Dictionary<string, string> En = new Dictionary<string, string>
        {
            { "Menu.Open",          "Open n8n" },
            { "Menu.Start",         "Start n8n" },
            { "Menu.Stop",          "Stop n8n" },
            { "Menu.Restart",       "Restart n8n" },
            { "Menu.Logs",          "View logs" },
            { "Menu.CopyUrl",       "Copy URL" },
            { "Menu.Update",        "Update n8n" },
            { "Menu.DataFolder",    "Open data folder" },
            { "Menu.AutoStart",     "Start with Windows" },
            { "Menu.About",         "About" },
            { "Menu.Exit",          "Quit" },
            { "Status.Idle",        "n8n: stopped" },
            { "Status.Starting",    "n8n: starting…" },
            { "Status.Installing",  "Downloading n8n… see the console window for live progress" },
            { "Status.Running",     "n8n: running — {0}" },
            { "Status.Stopping",    "n8n: stopping…" },
            { "Status.Error",       "n8n: error — check logs" },
            { "Dialog.InstallTitle","First-time n8n install" },
            { "Dialog.InstallBody", "Downloading n8n for the first time. Requires internet.\n\nA console window will open showing live npm progress.\nTypically takes 5–15 minutes, longer on slow connections or behind a corporate proxy." },
            { "Dialog.UpdateTitle", "Update n8n" },
            { "Dialog.UpdateBody",  "Fetching the latest n8n. Please wait." },
            { "Dialog.InstallFail", "Failed to install n8n.\n\nSee logs for details.\n\nError:\n{0}" },
            { "Dialog.UpdateFail",  "Failed to update n8n.\n\n{0}" },
            { "Dialog.AboutBody",   "n8n Tray Launcher\nVersion {0}\n\nn8n: {1}\n\nWebsite: https://n8n.io\nDocs: https://docs.n8n.io" },
            { "Error.NodeMissing",  "Bundled Node.js was not found.\nPlease re-run the installer." },
            { "Balloon.Ready",        "n8n is running\n{0}\nLeft-click the tray icon to open it anytime" },
            { "Balloon.ReadyShifted", "n8n is running\n{0}\n\n(Default port 5678 was in use, so n8n moved to port {1}. Always use the tray icon — it picks the right port.)" },
            { "Balloon.UrlCopied",    "URL copied: {0}" },
        };

        public static string T(string key)
        {
            var table = IsKorean() ? Ko : En;
            string value;
            return table.TryGetValue(key, out value) ? value : key;
        }

        public static string T(string key, params object[] args)
        {
            return string.Format(T(key), args);
        }

        private static bool IsKorean()
        {
            var culture = CultureInfo.CurrentUICulture;
            return culture != null && culture.TwoLetterISOLanguageName == "ko";
        }
    }
}
