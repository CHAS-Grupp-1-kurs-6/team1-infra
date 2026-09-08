# Lag 1 – infrastrukturlogg

**Kurs:** 6 – Avancerad IT-säkerhet  
**GCP-projekt:** `itsx25-lab`  
**GitHub-org:** `CHAS-Grupp-1-kurs-6`  
**Repository:** `team1-infra`  
**Team:** 1  
**Datum:** 2026-09-07 – 2026-09-08

---

# Del 1 – Infrastruktur och Terraform

## Fas 1 – Bootstrap

Vi packade upp det tillhandahållna Terraform-projektet och började med bootstrap-modulen.

I `bootstrap/main.tf` hittades en syntaxbugg där en avslutande klammer saknades i en `google_storage_bucket`-resurs. Felet korrigerades.

Därefter fylldes `terraform.tfvars` i med:

```hcl
project_id = "itsx25-lab"
team_id    = 1
```

Vi körde:

```bash
terraform init
terraform apply
```

Bootstrap skapade bland annat:

- Terraform State-bucket: `team1-tfstate-920afb25`
- CI/CD-servicekonto: `team1-cicd@itsx25-lab.iam.gserviceaccount.com`

---

## Fas 2 – State-migrering

Bootstrap-modulens state låg initialt lokalt.

Vi avkommenterade därför:

```hcl
backend "gcs" {
  bucket = "team1-tfstate-920afb25"
  prefix = "terraform/bootstrap-state"
}
```

och körde:

```bash
terraform init -migrate-state
```

Bootstrap-state flyttades därmed från lokal disk till GCP Cloud Storage.

---

## Fas 3 – GitHub-repository och första deployment

Vi skapade det privata GitHub-repot:

```text
CHAS-Grupp-1-kurs-6/team1-infra
```

Lokalt Git-repository initierades och SSH-remote konfigurerades.

För root-modulen skapades bland annat:

```text
terraform.tfvars
backend.tf
```

Root-state använde samma state-bucket men ett separat prefix:

```text
terraform/state
```

### Initial CI/CD-autentisering

Innan Workload Identity Federation implementerades användes en Service Account Key för GitHub Actions.

Nyckeln hämtades från Terraform-output:

```bash
terraform output -raw cicd_service_account_key_json | base64 -d
```

och lades in i GitHub som repository-secret:

```text
GCP_SA_KEY
```

Koden pushades därefter till `main`.

---

# Fas 4 – Branch protection

En ruleset sattes upp för `main`.

Reglerna omfattade bland annat:

- Pull Request krävs
- 2 godkännanden
- Status-check `Format & Validate` måste vara grön

Vi noterade samtidigt att GitHub-rulesets inte kunde enforced fullt ut för privata repositories på organisationens nuvarande plan-nivå. GitHub Team krävs för full enforcement.

Det dokumenterades som en känd begränsning.

Root-modulen deployades därefter via CI/CD och skapade bland annat:

- VM
- nätverk
- jumphost

SSH-nyckeln för användaren `malcolm` lades till i Terraform-konfigurationen.

---

# Fas 5 – Workload Identity Federation

## Problem med statisk Service Account Key

Vi ville ersätta den långlivade:

```text
GCP_SA_KEY
```

med nyckellös autentisering via Workload Identity Federation (WIF).

Tre separata behörighets-/konfigurationsproblem upptäcktes.

### 1. IAM-behörighet

Gruppen:

```text
itsx25@chasacademy.se
```

saknade:

```text
roles/iam.workloadIdentityPoolAdmin
```

Läraren Dennis beviljade rollen till gruppen.

### 2. Felaktigt gcloud-konto

`gcloud` på datorn var inloggat med ett gammalt tjänstekonto från en annan kurs.

Vi loggade därför om med rätt Chas-konto och korrigerade både:

```text
gcloud config
```

och:

```text
gcloud auth application-default login
```

### 3. IAM Credentials API

Följande API saknades:

```text
iamcredentials.googleapis.com
```

Det aktiverades:

```bash
gcloud services enable iamcredentials.googleapis.com
```

Efter detta kunde WIF konfigureras.

## WIF deployment

Terraform skapade:

- Workload Identity Pool
- Workload Identity Provider
- IAM-bindning mellan GitHub och CI/CD-servicekontot

GitHub Actions konfigurerades med:

```text
WORKLOAD_IDENTITY_PROVIDER
CICD_SERVICE_ACCOUNT
```

som repository-variabler.

Ändringen gjordes på:

```text
feature/wif-deploy
```

En `terraform fmt`-miss i `bootstrap/terraform.tfvars` gjorde att den första PR-checken failade.

Felet korrigerades.

PR:en öppnades och mergades till `main`.

Därefter verifierades:

```text
Deploy Infrastructure
```

som grön.

CI/CD fungerade nu med Workload Identity Federation utan:

```text
GCP_SA_KEY
```

---

# Fas 6 – Jumphost och intern åtkomst

Jumphosten identifierades som:

```text
34.51.158.253
```

SSH användes för åtkomst.

Vi använde även SSH Dynamic Port Forwarding/SOCKS5 för att kunna nå Spectre via jumphosten.

Exempel:

```bash
ssh -D 1080 malcolm@34.51.158.253
```

Spectre kunde nås via proxy från ett separat Chrome-fönster.

Vi verifierade att vi befann oss i Team 1:s interna nät:

```text
10.0.1.0/24
```

Detta bekräftade att jumphosten fungerade som den avsedda vägen in mot den interna labbmiljön.

---

# Fas 7 – SSH-åtkomst för laget

Vi lade till Samuel, Abdulghani och Mert i:

```text
ssh_users
```

Varje person hanterades genom separat PR och deployment via GitHub Actions.

Samuel och Mert fungerade direkt.

## Abdulghani – felsökning

Abdulghani fick:

```text
Permission denied (publickey)
```

trots att nyckeln såg korrekt ut.

Vi felsökte stegvis:

1. Kontrollerade att Terraform-ändringen verkligen deployats.
2. Kontrollerade rättigheter på `/home/abdulghani/.ssh/`.
3. Kontrollerade rättigheter på `authorized_keys`.
4. Kontrollerade `sshd`-konfigurationen.
5. Kontrollerade kontostatus.
6. Jämförde SSH-nyckelns fingeravtryck på server och klient.

Det avgörande fyndet var att fingeravtrycken var olika trots att nyckeltexten såg identisk ut med vanlig `cat`.

Det pekade på ett osynligt kopieringsfel, sannolikt orsakat av överföringen via Discord.

### Lösning

Abdulghani genererade ett helt nytt nyckelpar.

Den nya publika nyckeln lades in genom en separat PR:

```text
fix/abdulghani-ssh-key
```

PR:en mergades och deployment kördes.

SSH fungerade därefter.

### Lärdom

Vid:

```text
Permission denied (publickey)
```

bör nyckelfingeravtryck jämföras tidigt:

```bash
ssh-keygen -l -f authorized_keys
```

Det är betydligt mer tillförlitligt än att bara jämföra den text som visas i filen.

---

# Del 2 – Spectre Security Assessment

**Datum:** 2026-09-08

## Syfte

Efter att infrastrukturen var deployad genomfördes en säkerhetsassessment av Spectre.

Målet var att:

- förstå Spectres funktioner
- undersöka nätverksåtkomst
- testa LookingGlass
- undersöka DNS-provisioneringen
- identifiera exponerad information
- hitta de två flaggorna
- dokumentera relevanta säkerhetsfynd

Spectre innehöll bland annat:

```text
DNS – Subdomain Registration
LookingGlass – Network Diagnostics
Flag – Flag Submission
```

---

# 1. LookingGlass

LookingGlass användes för att testa nätverkskommunikation från Spectres edge.

Vi testade bland annat interna adresser.

En viktig adress som undersöktes var:

```text
172.18.0.3
```

LookingGlass kunde användas som en nätverksdiagnostikpunkt från Spectre-miljön.

Den första flaggan hittades genom LookingGlass-funktionen och verifierades på Spectres Flag-sida.

Efter detta visade Spectre:

```text
Team 1
1/2 flags
```

Det innebar att en flagga återstod.

---

# 2. Hint för Workshop 1

En central hint var:

```text
It's not about how it was built; it's about the state left behind.
```

Detta gjorde Terraform state relevant för den fortsatta undersökningen.

Vi började därför undersöka både infrastrukturen och vad som hade lämnats kvar i state efter deployment.

---

# 3. DNS – registrerad subdomän

Spectre visade att Team 1 redan hade en registrerad domän:

```text
dnsflag.itsx25.chas-lab.dev
```

Detta blev nästa huvudsakliga undersökningsspår.

## A-record

På jumphosten saknades först `dig` och `nc`.

Vi installerade:

```bash
sudo apt-get update
sudo apt-get install -y dnsutils netcat-openbsd
```

Därefter:

```bash
dig dnsflag.itsx25.chas-lab.dev
```

Resultatet var:

```text
dnsflag.itsx25.chas-lab.dev. 300 IN A 34.51.128.150
```

IP-adressen:

```text
34.51.128.150
```

verifierades även mot:

```bash
dig @8.8.8.8 dnsflag.itsx25.chas-lab.dev
dig @1.1.1.1 dnsflag.itsx25.chas-lab.dev
```

Båda gav samma IP.

Det visade att DNS-posten var publikt resolverbar.

---

# 4. Auktoritativ DNS

Vi identifierade nameservern:

```bash
dig NS itsx25.chas-lab.dev
```

Resultat:

```text
ns1.chas-lab.dev.
```

SOA kontrollerades:

```bash
dig SOA itsx25.chas-lab.dev
```

Det bekräftade:

```text
ns1.chas-lab.dev.
hostadmin.itsx25.chas-lab.dev.
```

Därefter frågade vi den auktoritativa DNS-servern direkt:

```bash
dig @ns1.chas-lab.dev dnsflag.itsx25.chas-lab.dev A
```

Resultatet innehöll `AA` (Authoritative Answer) och bekräftade:

```text
34.51.128.150
```

---

# 5. DNS-records

För att undersöka om flaggan var gömd direkt i DNS kontrollerades flera record-typer.

## TXT

```bash
dig @ns1.chas-lab.dev dnsflag.itsx25.chas-lab.dev TXT
```

Ingen TXT-record hittades.

## CNAME

```bash
dig CNAME dnsflag.itsx25.chas-lab.dev
```

Ingen CNAME hittades.

## ANY

```bash
dig @ns1.chas-lab.dev dnsflag.itsx25.chas-lab.dev ANY
```

Resultatet innehöll endast A-recordet:

```text
34.51.128.150
```

### Slutsats

Flaggan låg inte direkt i DNS som en TXT-, CNAME- eller annan uppenbar record.

DNS-spåret gav däremot viktig information om:

- domän
- IP-adress
- nameserver
- SOA
- auktoritativ DNS

---

# 6. HTTP/HTTPS

IP-adressen testades med HTTP:

```bash
curl -vk http://34.51.128.150/
```

HTTP svarade med redirect:

```text
HTTP/1.1 301 Moved Permanently
Location: https://34.51.128.150/
```

HTTPS testades därefter.

HTTPS mot IP-adressen gav:

```text
HTTP/2 404
404 page not found
```

TLS-certifikatet visade:

```text
CN=TRAEFIK DEFAULT CERT
```

Den registrerade DNS-domänen testades också:

```bash
curl -vk https://dnsflag.itsx25.chas-lab.dev/
```

TLS fungerade och certifikatet matchade:

```text
itsx25.chas-lab.dev
```

Men root-endpointen gav:

```text
HTTP/2 404
404 page not found
```

Vi testade även:

```text
/flag
```

men även detta gav `404`.

### Slutsats

DNS och TLS fungerade, men flaggan fanns inte direkt på root-endpointen eller `/flag`.

---

# 7. Spectre API/HTML-försök

Vi försökte även undersöka Spectres DNS-sida direkt:

```bash
curl -sk https://spectre.itsx25.chas-lab.dev/dns
```

Det gav:

```text
Forbidden
```

Vi försökte även identifiera JavaScript/API-anrop:

```bash
curl -sk https://spectre.itsx25.chas-lab.dev/dns \
  | grep -oiE '<script[^>]+src="[^"]+'
```

samt:

```bash
curl -sk https://spectre.itsx25.chas-lab.dev/dns \
  | grep -aiE 'api|dns|register|flag|domain|fetch'
```

Det gav ingen användbar direkt endpoint.

---

# 8. SSH SOCKS5

För att nå Spectre via jumphosten användes SSH dynamic forwarding.

Exempel:

```bash
ssh -N -D 1081 malcolm@34.51.158.253
```

Ett tidigare försök med port `1080` misslyckades eftersom porten redan var upptagen:

```text
Address already in use
```

Vi bytte därför till:

```text
1081
```

När tunneln var korrekt igång kunde trafik skickas genom jumphosten med:

```bash
curl --socks5-hostname 127.0.0.1:1081 ...
```

Ett viktigt felsökningsmisstag var att försöka köra kommandon i samma terminal som:

```text
ssh -N -D 1081
```

Den terminalen ska lämnas öppen eftersom SSH-processen håller tunneln aktiv.

Rätt upplägg är:

```text
Terminal 1:
ssh -N -D 1081 malcolm@34.51.158.253

Terminal 2:
curl --socks5-hostname 127.0.0.1:1081 ...
```

---

# 9. Terraform State – avgörande fynd

När DNS- och webbspåren inte gav den återstående flaggan gick vi tillbaka till Terraform state.

Terraform visade bland annat:

```bash
terraform state list
```

Resurser som identifierades inkluderade:

```text
data.google_project.project
google_iam_workload_identity_pool.github
google_iam_workload_identity_pool_provider.github
google_project_iam_member.cicd_editor
google_service_account.cicd
google_service_account_iam_member.cicd_workload_identity
google_service_account_key.cicd
google_storage_bucket.terraform_state
google_storage_bucket_iam_member.read_bucket
random_id.bucket_suffix
```

State-bucketen var:

```text
team1-tfstate-920afb25
```

---

# 10. Service Account Key i Terraform State

En viktig säkerhetsobservation var att Terraform state innehöll information relaterad till:

```text
google_service_account_key.cicd
```

State innehöll känslig information kopplad till CI/CD-servicekontot.

Detta var särskilt relevant eftersom den gamla CI/CD-lösningen använde en långlivad Service Account Key.

Det innebar att Terraform state i praktiken behövde behandlas som känslig information.

---

# 11. Base64 och den andra flaggan

Den avgörande ledtråden hittades genom att söka efter secret data i:

```text
terraform.tfstate
```

En base64-kodad sträng hittades:

```text
SVRTWDI1e3QzcnI0ZjBybV9zdDR0M19yM3YzNGxzX3RoM19zM2NyM3RzfQ==
```

Vi verifierade innehållet genom att avkoda Base64:

```bash
echo 'SVRTWDI1e3QzcnI0ZjBybV9zdDR0M19yM3YzNGxzX3RoM19zM2NyM3RzfQ==' | base64 -d
```

Resultatet blev:

```text
ITSX25{t3rr4f0rm_st4t3_r3v34ls_th3_s3cr3ts}
```

Detta var den andra flaggan.

Flaggan verifierades därefter via Spectres Flag-sida.

Resultat:

```text
2/2 flags
```

---

# 12. Vad vi lärde oss av flaggfyndet

Den viktiga säkerhetslärdomen var inte enbart att Base64 kunde avkodas.

Base64 är **kodning och inte kryptering**.

Problemet var att en känslig sträng hade lämnats kvar i Terraform state.

En person med tillräcklig åtkomst till state kunde därför läsa information som inte var avsedd att vara publik.

Detta visar varför:

```text
terraform.tfstate
```

måste behandlas som känslig information.

---

# 13. Samlad undersökningskedja

```text
Terraform deployment
        |
        v
Jumphost
34.51.158.253
        |
        v
SSH / SOCKS5
        |
        v
Spectre
        |
        +----------------------+
        |                      |
        v                      v
LookingGlass                 DNS
        |                      |
        v                      v
Flagga 1             dnsflag.itsx25.chas-lab.dev
                               |
                               v
                        34.51.128.150
                               |
                       +-------+-------+
                       |       |       |
                       v       v       v
                       A     TXT    CNAME/ANY
                       |       |       |
                       |    ingen     ingen
                       |
                       v
                    HTTPS
                       |
                       v
                      404
                       |
                       v
                 Terraform State
                       |
                       v
                 terraform.tfstate
                       |
                       v
                Base64-kodad secret
                       |
                       v
                  base64 -d
                       |
                       v
                    Flagga 2
```

---

# 14. Säkerhetsfynd

## Fynd 1 – Secrets i Terraform State

Terraform state innehöll känslig information.

**Risk:**

En angripare med åtkomst till state kan potentiellt få information som kan användas för vidare åtkomst.

**Rekommendation:**

- Begränsa IAM på state-bucketen.
- Använd least privilege.
- Skydda state-bucketen mot obehörig läsning.
- Undvik att lagra secrets direkt i Terraform state när det finns bättre alternativ.
- Rotera credentials om de har exponerats.

---

## Fynd 2 – Långlivad Service Account Key

Den ursprungliga CI/CD-lösningen använde:

```text
GCP_SA_KEY
```

som GitHub-secret.

Detta innebär att en läckt nyckel potentiellt kan användas utanför GitHub Actions.

Under projektet ersattes detta med Workload Identity Federation.

**Rekommendation:**

När WIF är verifierad bör den gamla:

```text
GCP_SA_KEY
```

tas bort.

---

## Fynd 3 – För omfattande CI/CD-behörighet

CI/CD-servicekontot hade:

```text
roles/editor
```

Det innebär betydligt större åtkomst än vad som normalt krävs för en strikt least-privilege-lösning.

**Risk:**

Om den gamla service-account-nyckeln läcker kan angriparen få omfattande åtkomst till projektets resurser.

**Rekommendation:**

Ersätt breda roller med specifika roller för de operationer CI/CD faktiskt behöver.

---

# 15. Förbättringar efter assessment

Efter undersökningen bör följande genomföras:

- Ta bort den gamla `GCP_SA_KEY` från GitHub när WIF är verifierad.
- Kontrollera om den gamla Service Account Key fortfarande är aktiv.
- Rotera/revokera gamla credentials.
- Kontrollera åtkomst till Terraform state-bucketen.
- Minimera IAM-behörigheter för CI/CD.
- Undvik secrets direkt i Terraform state där möjligt.
- Behåll WIF för GitHub Actions.
- Dokumentera kända begränsningar i GitHub branch protection.
- Behåll SSH-felsökningsmetoden med fingerprint-verifiering som standard.

---

# 16. Slutstatus

## Infrastruktur

- Bootstrap: **KLAR**
- Terraform State-migrering: **KLAR**
- GitHub repository: **KLAR**
- Branch protection: **KLAR**
- Root deployment: **KLAR**
- Workload Identity Federation: **KLAR**
- Jumphost: **KLAR**
- SSH för teammedlemmar: **KLAR**

## Spectre

- LookingGlass: **LÖST**
- DNS-undersökning: **GENOMFÖRD**
- Auktoritativ DNS identifierad: **JA**
- HTTP/HTTPS: **UNDERSÖKT**
- SOCKS5/SSH: **UNDERSÖKT**
- Terraform state: **UNDERSÖKT**
- Base64-secret: **HITTAD**
- Flagga 1: **LÖST**
- Flagga 2: **LÖST**
- Totalt: **2/2**

---

# Sammanfattning

Projektet började med att bygga och deploya en GCP-baserad infrastruktur med Terraform och GitHub Actions.

Vi gick därefter från en statisk Service Account Key till Workload Identity Federation för att förbättra säkerheten i CI/CD-flödet.

Under Spectre-assessmenten undersökte vi intern nätverksåtkomst, LookingGlass, DNS, DNS-records, HTTP/HTTPS, SSH och SOCKS5.

Den första flaggan hittades genom LookingGlass.

Den andra flaggan hittades genom att följa ledtråden om det "state left behind". Terraform state undersöktes och en base64-kodad secret hittades i `terraform.tfstate`. Genom att avkoda strängen med `base64 -d` kunde den andra flaggan identifieras och verifieras.

Det viktigaste säkerhetsfyndet var att Terraform state kunde innehålla känslig information. Detta visar vikten av att skydda state, använda least privilege och undvika långlivade statiska credentials när Workload Identity Federation kan användas istället.
