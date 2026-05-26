# n8n Windows Installer

비개발자도 더블클릭 한 번으로 n8n을 설치/실행할 수 있게 해주는 Windows 전용 설치 패키지.

- **결과물**: `n8n-installer-<version>.exe` 단일 파일 (~35MB)
- **포함**: 포터블 Node.js LTS + 트레이 런처 + 부트스트랩 스크립트
- **사용자 흐름**: 설치 EXE 더블클릭 → 트레이 아이콘 등장 → n8n 자동 시작 → 브라우저 자동 오픈

최종 사용자용 안내는 [`INSTALL_GUIDE.md`](./INSTALL_GUIDE.md) 참조.

## 아키텍처

```
n8n-installer.exe (Inno Setup)
└─ %LOCALAPPDATA%\Programs\n8n\
   ├─ node\               # 포터블 Node.js LTS
   ├─ N8nTray.exe         # 트레이 런처 (C# WinForms)
   ├─ bootstrap\          # PowerShell 부트스트랩 스크립트
   │  ├─ first-run-install.ps1
   │  ├─ update-n8n.ps1
   │  └─ helpers.ps1
   ├─ n8n-data\           # 첫 실행 시 npm install n8n으로 생성
   │  └─ node_modules\n8n\
   └─ icon.ico

사용자 데이터: %USERPROFILE%\.n8n\        # n8n 공식 기본값과 호환
```

## 빌드 환경

빌드는 **Windows에서만** 가능합니다. 다음 두 가지를 설치하면 모든 의존성이 갖춰집니다:

1. **Visual Studio 2022 Community** (무료, 전체 IDE) — [다운로드](https://visualstudio.microsoft.com/vs/community/)
   - 또는 더 가벼운 [Visual Studio Build Tools 2022](https://visualstudio.microsoft.com/downloads/?q=build+tools) 만 설치해도 됨
   - 설치 시 **".NET 데스크톱 빌드 도구"** (.NET desktop build tools) 워크로드 체크 → MSBuild + .NET Framework 4.7.2 타겟 팩이 함께 설치됨
2. **Inno Setup 6** — [jrsoftware.org/isdl.php](https://jrsoftware.org/isdl.php)

| 도구 | 버전 | 비고 |
|------|------|------|
| Windows | 10/11 x64 | — |
| PowerShell | 5.1+ | OS 내장 |
| MSBuild | 16+ (VS 2019/2022 포함분) | `build.ps1` 가 `vswhere` 로 자동 탐지 |
| .NET Framework Targeting Pack | 4.7.2 | VS 설치 시 "데스크톱 .NET" 워크로드와 함께 |
| Inno Setup | 6.x | `%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe` |

`build.ps1` 는 MSBuild와 ISCC를 자동으로 찾으니, 표준 위치에 설치만 했다면 추가 설정 불필요합니다.

## 빌드 방법

```powershell
cd windows-installer
.\scripts\build.ps1 -Version 1.0.0
```

빌드 단계:

1. `download-nodejs.ps1` — Node.js LTS 포터블 zip을 `vendor/` 로 다운로드 후 압축 해제
2. `msbuild tray-app/N8nTray.csproj /p:Configuration=Release` — 트레이 EXE 빌드
3. `ISCC.exe setup.iss /DAppVersion=<version>` — 인스톨러 EXE 생성
4. `verify-build.ps1` — 산출물 sanity check (크기, SHA256)

산출물: `build/n8n-installer-<version>.exe`

## 빠른 검증

```powershell
.\scripts\verify-build.ps1 -InstallerPath .\build\n8n-installer-1.0.0.exe
```

스모크 테스트(VM 권장):

1. 클린 Windows 11 VM (Node.js 미설치)에서 인스톨러 실행
2. 트레이 아이콘 등장 확인
3. "n8n 열기" → 브라우저로 `http://localhost:5678` 자동 오픈
4. 워크플로 저장 → 트레이 "n8n 중지/시작" → 데이터 유지 확인
5. 제어판 → 제거 → `%USERPROFILE%\.n8n` 보존 확인

## 디렉터리 구조

```
windows-installer/
├── README.md                  # (이 문서)
├── INSTALL_GUIDE.md           # 최종 사용자용 한국어 매뉴얼
├── setup.iss                  # Inno Setup 스크립트
├── assets/
│   ├── icon.ico               # 아이콘 (16/32/48/256)
│   ├── banner.bmp             # 설치 마법사 배너 (497x314)
│   └── license-ko.txt         # 한국어 라이선스 표시
├── tray-app/                  # C# WinForms 트레이 런처
│   ├── N8nTray.csproj
│   ├── Program.cs
│   ├── TrayContext.cs
│   ├── N8nProcess.cs
│   ├── PortReadiness.cs
│   ├── Localization.cs
│   └── Properties/AssemblyInfo.cs
├── bootstrap/                 # PowerShell 부트스트랩
│   ├── first-run-install.ps1
│   ├── update-n8n.ps1
│   └── helpers.ps1
└── scripts/                   # 빌드 스크립트
    ├── build.ps1
    ├── download-nodejs.ps1
    └── verify-build.ps1
```

## 자산 (assets/) 준비

`icon.ico` 와 `banner.bmp` 는 바이너리이므로 저장소에 포함되지 않을 수 있습니다. 첫 빌드 전 다음을 준비하세요:

- `icon.ico`: 256x256 + 48x48 + 32x32 + 16x16 멀티 해상도 ICO. n8n 공식 SVG에서 생성 가능
- `banner.bmp`: 497x314, 24-bit BMP. Inno Setup `WizardImageFile` 사양

자산이 없으면 `setup.iss` 의 `SetupIconFile` / `WizardImageFile` 라인을 주석 처리하면 기본값으로 빌드됩니다.

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| `ISCC : command not found` | Inno Setup 6 설치, PATH 추가 또는 `-InnoSetupPath` 옵션 전달 |
| `MSB1009: 프로젝트 파일이 존재하지 않습니다` | `pwd` 가 `windows-installer/` 인지 확인 |
| 빌드 EXE 백신 차단 | 코드 서명 미적용 — 임시로 빌드 폴더를 백신 예외 등록 |
| 클린 VM 첫 실행 시 npm 실패 | 인터넷/프록시 확인 — 사용자 매뉴얼 참고 |

## 향후 개선 (Out of Scope, v2 검토)

- 코드 서명 인증서 도입 (SmartScreen 경고 제거)
- GitHub Actions Windows runner 자동 빌드/릴리즈
- 자동 업데이트 (Squirrel.Windows)
- ARM64 빌드
- Microsoft Store / winget 배포

## 라이선스

n8n Fair-Code License 를 따릅니다. 자세한 내용은 저장소 루트의 `LICENSE.md` 참조.
