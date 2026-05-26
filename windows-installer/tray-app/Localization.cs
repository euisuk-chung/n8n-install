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
            { "Menu.Update",        "n8n 업데이트" },
            { "Menu.DataFolder",    "데이터 폴더 열기" },
            { "Menu.AutoStart",     "Windows 시작 시 자동 실행" },
            { "Menu.About",         "정보" },
            { "Menu.Exit",          "종료" },
            { "Status.Idle",        "n8n: 중지됨" },
            { "Status.Starting",    "n8n: 시작 중…" },
            { "Status.Installing",  "n8n 본체 다운로드 중… (1~2분 소요)" },
            { "Status.Running",     "n8n: 실행 중 — {0}" },
            { "Status.Stopping",    "n8n: 중지 중…" },
            { "Status.Error",       "n8n: 오류 발생 — 로그를 확인하세요" },
            { "Dialog.InstallTitle","n8n 처음 설치" },
            { "Dialog.InstallBody", "n8n 본체를 처음 다운로드합니다. 인터넷 연결이 필요합니다.\n\n(1~2분 소요)" },
            { "Dialog.UpdateTitle", "n8n 업데이트" },
            { "Dialog.UpdateBody",  "최신 n8n 버전을 받아옵니다. 잠시만 기다려 주세요." },
            { "Dialog.InstallFail", "n8n 설치에 실패했습니다.\n\n자세한 내용은 로그를 확인해 주세요.\n\n오류:\n{0}" },
            { "Dialog.UpdateFail",  "n8n 업데이트에 실패했습니다.\n\n{0}" },
            { "Dialog.AboutBody",   "n8n Tray Launcher\n버전 {0}\n\nn8n: {1}\n\n공식: https://n8n.io\n매뉴얼: https://docs.n8n.io" },
            { "Error.NodeMissing",  "Node.js 번들을 찾을 수 없습니다.\n인스톨러를 다시 실행해 주세요." },
        };

        private static readonly Dictionary<string, string> En = new Dictionary<string, string>
        {
            { "Menu.Open",          "Open n8n" },
            { "Menu.Start",         "Start n8n" },
            { "Menu.Stop",          "Stop n8n" },
            { "Menu.Restart",       "Restart n8n" },
            { "Menu.Logs",          "View logs" },
            { "Menu.Update",        "Update n8n" },
            { "Menu.DataFolder",    "Open data folder" },
            { "Menu.AutoStart",     "Start with Windows" },
            { "Menu.About",         "About" },
            { "Menu.Exit",          "Quit" },
            { "Status.Idle",        "n8n: stopped" },
            { "Status.Starting",    "n8n: starting…" },
            { "Status.Installing",  "Downloading n8n… (1–2 min)" },
            { "Status.Running",     "n8n: running — {0}" },
            { "Status.Stopping",    "n8n: stopping…" },
            { "Status.Error",       "n8n: error — check logs" },
            { "Dialog.InstallTitle","First-time n8n install" },
            { "Dialog.InstallBody", "Downloading n8n for the first time. Requires internet.\n\n(1–2 minutes)" },
            { "Dialog.UpdateTitle", "Update n8n" },
            { "Dialog.UpdateBody",  "Fetching the latest n8n. Please wait." },
            { "Dialog.InstallFail", "Failed to install n8n.\n\nSee logs for details.\n\nError:\n{0}" },
            { "Dialog.UpdateFail",  "Failed to update n8n.\n\n{0}" },
            { "Dialog.AboutBody",   "n8n Tray Launcher\nVersion {0}\n\nn8n: {1}\n\nWebsite: https://n8n.io\nDocs: https://docs.n8n.io" },
            { "Error.NodeMissing",  "Bundled Node.js was not found.\nPlease re-run the installer." },
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
