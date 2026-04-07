# GitHub Actions para gerar o app iOS

## O que este repositório já terá

- Workflow para validar build no simulador.
- Workflow para gerar `.ipa` manualmente.
- Scheme compartilhado do Xcode para o CI enxergar o target.
- Ícones placeholder gerados a partir da logo atual.

## Passo a passo

1. Crie um repositório vazio no GitHub.
2. No terminal desta pasta, rode:

```powershell
git init
git add .
git commit -m "Prepare iOS GitHub Actions build"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

3. No GitHub, abra `Settings > Secrets and variables > Actions`.
4. Crie estes `Repository secrets`:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`
- `TEAM_ID`
- `CODE_SIGN_IDENTITY`
- `PROVISIONING_PROFILE_NAME`

5. Rode primeiro o workflow `iOS Simulator Build`.
6. Se o build do simulador passar, rode o workflow `iOS Device IPA`.
7. Baixe o artefato `.ipa` gerado em `Actions`.

## Como preencher os secrets

- `BUILD_CERTIFICATE_BASE64`: arquivo `.p12` do certificado Apple convertido em Base64.
- `P12_PASSWORD`: senha usada ao exportar o `.p12`.
- `BUILD_PROVISION_PROFILE_BASE64`: arquivo `.mobileprovision` convertido em Base64.
- `KEYCHAIN_PASSWORD`: senha temporária para o keychain do runner.
- `TEAM_ID`: ID do time Apple Developer.
- `CODE_SIGN_IDENTITY`: normalmente algo como `Apple Distribution: Seu Nome ou Empresa (TEAMID)`.
- `PROVISIONING_PROFILE_NAME`: nome exato do provisioning profile.

## Comandos úteis para Base64

No macOS:

```bash
base64 -i certificado.p12 | pbcopy
base64 -i perfil.mobileprovision | pbcopy
```

No Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\caminho\certificado.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\caminho\perfil.mobileprovision"))
```

## Observações

- Este fluxo gera IPA para instalação fora da App Store, usando export `ad-hoc`.
- Para instalar no iPhone, o aparelho precisa estar incluído no provisioning profile ad hoc.
- Sem conta Apple Developer e assinatura válidas, o workflow do IPA não fecha.
