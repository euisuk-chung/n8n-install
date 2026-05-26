![Banner image](https://user-images.githubusercontent.com/10284570/173569848-c624317f-42b1-45a6-ab09-f0ea3c247648.png)

# n8n - Secure Workflow Automation for Technical Teams

n8n is a workflow automation platform that gives technical teams the flexibility of code with the speed of no-code. With 400+ integrations, native AI capabilities, and a fair-code license, n8n lets you build powerful automations while maintaining full control over your data and deployments.

![n8n.io - Screenshot](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-screenshot-readme.png)

## Key Capabilities

- **Code When You Need It**: Write JavaScript/Python, add npm packages, or use the visual interface
- **AI-Native Platform**: Build AI agent workflows based on LangChain with your own data and models
- **Full Control**: Self-host with our fair-code license or use our [cloud offering](https://app.n8n.cloud/login)
- **Enterprise-Ready**: Advanced permissions, SSO, and air-gapped deployments
- **Active Community**: 400+ integrations and 900+ ready-to-use [templates](https://n8n.io/workflows)

## Quick Start

Try n8n instantly with [npx](https://docs.n8n.io/hosting/installation/npm/) (requires [Node.js](https://nodejs.org/en/)):

```
npx n8n
```

Or deploy with [Docker](https://docs.n8n.io/hosting/installation/docker/):

```
docker volume create n8n_data
docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

Access the editor at http://localhost:5678

### Windows (non-developers, double-click install)

If you're on Windows and don't want to deal with Node.js, npm, or a terminal, this fork ships a tray-based Windows installer under [`windows-installer/`](./windows-installer/).

**What the user gets**

1. Double-click `n8n-installer-<version>.exe`. A Korean/English wizard guides them through setup.
2. After install, an n8n icon appears in the system tray:
   - **Left-click / double-click** → opens the n8n editor in your browser
   - **Right-click** → Start/Stop n8n, view logs, update n8n, open data folder, toggle auto-start on boot
3. Workflows and credentials live at `%USERPROFILE%\.n8n` (the standard n8n location).

The installer bundles a portable Node.js LTS — no manual Node install required. The n8n payload itself is fetched from npm on the first launch (takes ~1–2 minutes; requires internet).

**End-user guide (Korean):** [`windows-installer/INSTALL_GUIDE.md`](./windows-installer/INSTALL_GUIDE.md) — share this with non-developers.
**Builder docs:** [`windows-installer/README.md`](./windows-installer/README.md)

**Getting the EXE**

- **Pre-built**: [Releases](https://github.com/euisuk-chung/n8n-install/releases) — if a release is published, download `n8n-installer-<version>.exe` from its Assets. If none is published yet, build it yourself below.
- **Build it yourself** on Windows 10/11:

  ```powershell
  git clone https://github.com/euisuk-chung/n8n-install.git
  cd n8n-install\windows-installer
  .\scripts\build.ps1 -Version 1.0.0
  # Output: build\n8n-installer-1.0.0.exe
  ```

  Prerequisites: [Visual Studio 2022 Community](https://visualstudio.microsoft.com/vs/community/) (or [Build Tools 2022](https://visualstudio.microsoft.com/downloads/?q=build+tools)) with the **.NET desktop build tools** workload, plus [Inno Setup 6](https://jrsoftware.org/isdl.php). `build.ps1` finds MSBuild via `vswhere` automatically.

- **Publish a release** (manual): build locally, then go to the [Releases page](https://github.com/euisuk-chung/n8n-install/releases) → **Draft a new release** → choose a tag → upload `build\n8n-installer-<version>.exe` as an asset → **Publish release**.

## Resources

- 📚 [Documentation](https://docs.n8n.io)
- 🔧 [400+ Integrations](https://n8n.io/integrations)
- 💡 [Example Workflows](https://n8n.io/workflows)
- 🤖 [AI & LangChain Guide](https://docs.n8n.io/advanced-ai/)
- 👥 [Community Forum](https://community.n8n.io)
- 📖 [Community Tutorials](https://community.n8n.io/c/tutorials/28)

## Support

Need help? Our community forum is the place to get support and connect with other users:
[community.n8n.io](https://community.n8n.io)

## License

n8n is [fair-code](https://faircode.io) distributed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) and [n8n Enterprise License](https://github.com/n8n-io/n8n/blob/master/LICENSE_EE.md).

- **Source Available**: Always visible source code
- **Self-Hostable**: Deploy anywhere
- **Extensible**: Add your own nodes and functionality

[Enterprise Licenses](mailto:license@n8n.io) available for additional features and support.

Additional information about the license model can be found in the [docs](https://docs.n8n.io/sustainable-use-license/).

## Contributing

Found a bug 🐛 or have a feature idea ✨? Check our [Contributing Guide](https://github.com/n8n-io/n8n/blob/master/CONTRIBUTING.md) for a setup guide & best practices.

## Join the Team

Want to shape the future of automation? Check out our [job posts](https://n8n.io/careers) and join our team!

## What does n8n mean?

**Short answer:** It means "nodemation" and is pronounced as n-eight-n.

**Long answer:** "I get that question quite often (more often than I expected) so I decided it is probably best to answer it here. While looking for a good name for the project with a free domain I realized very quickly that all the good ones I could think of were already taken. So, in the end, I chose nodemation. 'node-' in the sense that it uses a Node-View and that it uses Node.js and '-mation' for 'automation' which is what the project is supposed to help with. However, I did not like how long the name was and I could not imagine writing something that long every time in the CLI. That is when I then ended up on 'n8n'." - **Jan Oberhauser, Founder and CEO, n8n.io**
