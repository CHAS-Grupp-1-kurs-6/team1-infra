# Lag 1 – infrastrukturlogg

Kurs 6, Avancerad IT-säkerhet. GCP-projekt `itsx25-lab`, GitHub-org `CHAS-Grupp-1-kurs-6`, repo `team1-infra`. Datum: 2026-09-07.

## Fas 1 – Bootstrap

Packade upp det tillhandahållna Terraform-projektet och fixade en syntaxbugg i `bootstrap/main.tf` (saknad avslutande klammer på `google_storage_bucket`-resursen). Fyllde i `terraform.tfvars` med `project_id = "itsx25-lab"` och `team_id = 1`.

Körde `terraform init` och `terraform apply` i `bootstrap`. Skapade:

- State-bucket: `team1-tfstate-920afb25`
- CI/CD-tjänstekonto: `team1-cicd@itsx25-lab.iam.gserviceaccount.com`

## Fas 2 – State-migrering

Avkommenterade `backend "gcs"`-blocket i `bootstrap/main.tf` med rätt bucket-namn och prefix `terraform/bootstrap-state`. Körde `terraform init -migrate-state` så att bootstrap-modulens eget state flyttades från lokal disk till bucketen.

## Fas 3 – GitHub-repo och första push

Skapade privat repo `team1-infra` i `CHAS-Grupp-1-kurs-6`. Initierade git lokalt, la till SSH-remote, skapade `terraform.tfvars` och `backend.tf` för root-modulen (samma bucket, prefix `terraform/state`).

Hämtade CI/CD-nyckeln med `terraform output -raw cicd_service_account_key_json | base64 -d` och lade in den som repo-secret `GCP_SA_KEY` i GitHub. Pushade koden till `main`.

## Fas 4 – Branch protection

Satte upp en ruleset på `main`: pull request krävs, 2 godkännanden, status-check `Format & Validate` måste vara grön. Noterade att GitHub-rulesets inte enforcas fullt ut på organisationens nuvarande plan-nivå (kräver GitHub Team för privata repon), dokumenterat som känd begränsning.

Root-modulen deployades via CI/CD (VM, nätverk, jumphost). SSH-nyckel för `malcolm` lades till i `terraform.tfvars`.

## Fas 5 – Workload Identity Federation

Bytte bort den långlivade service account-nyckeln mot nyckellös autentisering.

Stötte på och löste tre separata behörighetsproblem innan det gick igenom:

1. Gruppen `itsx25@chasacademy.se` saknade rollen `roles/iam.workloadIdentityPoolAdmin`. Läraren (Dennis) beviljade rollen till gruppen.
2. `gcloud`-CLI:t på datorn var inloggad med ett trasigt gammalt tjänstekonto från en annan kurs. Loggade om med rätt Chas-konto, både för `gcloud config` och `gcloud auth application-default login`.
3. `iamcredentials.googleapis.com` (IAM Service Account Credentials API) var inte aktiverat i projektet. Aktiverades med `gcloud services enable`.

När det var löst:

- `terraform apply` i `bootstrap` skapade workload identity pool, provider och IAM-bindning.
- Lade in `WORKLOAD_IDENTITY_PROVIDER` och `CICD_SERVICE_ACCOUNT` som repo-variabler i GitHub.
- Committade och pushade `deploy.yml`-ändringen på branchen `feature/wif-deploy`.
- Fixade ett `terraform fmt`-fel i `bootstrap/terraform.tfvars` som fick första PR-checken att faila.
- Öppnade och mergade PR:en till `main`.
- Verifierade att "Deploy Infrastructure"-pipelinen går grön med WIF, utan `GCP_SA_KEY`.

## Verifiering av jumphost

SSH:ade in på jumphosten (`34.51.158.253`) med SOCKS5-proxy (`ssh -D 1080`). Nådde `spectre.itsx25.chas-lab.dev` via proxyn i ett separat Chrome-fönster, bekräftade rätt subnät (`10.0.1.0/24`, Team 1).

## SSH-åtkomst för resten av laget

Lade till Samuel, Abdulghani och Mert i `ssh_users`-listan i root-modulens `terraform.tfvars`, en PR per person/tillfälle, mergad till `main`, deployad via pipelinen.

Samuel och Mert fungerade direkt. Abdulghani fick genomgående `Permission denied (publickey)`, trots att den nyckel han skickat via Discord visuellt matchade den som låg i `terraform.tfvars` och i `authorized_keys` på jumphosten. Felsökningen gick igenom, i tur och ordning:

1. Kontrollerade att patchen/koden faktiskt deployats (den hade).
2. Kontrollerade filrättigheter och ägare på `/home/abdulghani/.ssh/` på jumphosten (korrekta, 700/600).
3. Kontrollerade `sshd`-konfigurationen för `AuthorizedKeysFile` (standard, ingen OS Login-konflikt).
4. Kontrollerade kontostatus (`passwd -S`, samma som fungerande konton).
5. Jämförde fingeravtrycket på servern (`ssh-keygen -l -f authorized_keys`) mot fingeravtrycket klienten erbjöd i `ssh -vvv`-loggen: **olika nycklar**, trots identisk text vid vanlig `cat`. Sannolikt ett osynligt kopieringsfel (troligen via Discord).

Lösning: Abdulghani genererade ett helt nytt nyckelpar, skickade den nya publika nyckeln, den lades in i en egen PR (`fix/abdulghani-ssh-key`) och mergades. Fungerade efter det.

Lärdom: vid `Permission denied (publickey)` trots att nyckeltexten ser rätt ut, jämför alltid fingeravtryck (`ssh-keygen -l`) på båda sidor innan man letar efter fel i behörigheter eller konfiguration, det är snabbare och mer definitivt.

## Kvarstående

- Diskutera i laget när den gamla `GCP_SA_KEY`-secreten ska tas bort, nu när WIF fungerar. Underlag för red team-reflektionen: vad en angripare skulle kunna göra med `roles/editor` på hela projektet om nyckeln läckt.
- Kristoffer väntar fortfarande på att bli tillagd i `ssh_users`, han var sjuk under sessionen.
- Fas 6, flaggorna via Spectre: nästa steg.
