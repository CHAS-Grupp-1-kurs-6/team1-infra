# Lag 1 – Security Issues

Kurs 6 – Avancerad IT-säkerhet  
GCP-projekt: `itsx25-lab`  
GitHub-org: `CHAS-Grupp-1-kurs-6`  
Repository: `team1-infra`

> Detta dokument används för att samla säkerhetsproblem, svagheter och tekniska förbättringsområden som identifieras under projektets säkerhetsarbete.
>
> Ett fynd ska verifieras innan det skapas som en GitHub Issue. Flaggor och CTF-resultat dokumenteras separat och ska inte behandlas som Issues.

---

## 🔴 Hög prioritet

### 1. Terraform State innehåller känslig information

**Status:** ☐ Att verifiera  
**Severity:** High  
**Ansvarig:** __________

#### Vad ska undersökas?

- Kontrollera `terraform.tfstate`.
- Kontrollera vilken känslig information som lagras i state.
- Kontrollera om credentials, privata nycklar eller andra secrets förekommer.
- Kontrollera vilka identiteter som kan läsa state-bucketen.
- Kontrollera om gamla state-versioner innehåller känslig information.
- Kontrollera om känsliga Terraform outputs är markerade som `sensitive`.

#### Risk

Terraform State kan innehålla känslig information. Om obehöriga får läsåtkomst till state kan informationen potentiellt användas för att angripa infrastrukturen.

#### Rekommenderad åtgärd

- Begränsa åtkomsten till state-bucketen.
- Använd least privilege.
- Undvik att lagra secrets i Terraform State när det går.
- Kontrollera och skydda versionshistorik.
- Markera relevanta outputs som `sensitive`.

#### Bevis / resultat

> Fylls i efter verifiering.

---

### 2. CI/CD Service Account har potentiellt för breda behörigheter

**Status:** ☐ Att verifiera  
**Severity:** High  
**Ansvarig:** __________

Service account:

`team1-cicd@itsx25-lab.iam.gserviceaccount.com`

#### Vad ska undersökas?

- Lista alla IAM-roller för servicekontot.
- Kontrollera om `roles/editor` används.
- Identifiera vilka permissions CI/CD faktiskt behöver.
- Bedöm om behörigheterna kan minskas.

#### Risk

En komprometterad CI/CD-identitet med mycket breda rättigheter kan ge en angripare stor åtkomst till GCP-projektet.

#### Rekommenderad åtgärd

Byt från breda roller till specifika roller som motsvarar de operationer CI/CD faktiskt behöver.

#### Bevis / resultat

> Fylls i efter verifiering.

---

### 3. Gammal GCP Service Account Key bör tas bort efter WIF

**Status:** ☐ Att verifiera  
**Severity:** High  
**Ansvarig:** __________

#### Vad ska undersökas?

- Kontrollera om `GCP_SA_KEY` fortfarande finns i GitHub.
- Kontrollera om workflow fortfarande använder `GCP_SA_KEY`.
- Kontrollera att WIF används av deployment.
- Kontrollera om den gamla service-account-nyckeln fortfarande är aktiv.
- Kontrollera om credentialn förekommer någon annanstans i repository eller Git-historik.

#### Risk

Långlivade service-account-nycklar innebär en större risk eftersom de kan användas utanför GitHub om de läcker.

#### Rekommenderad åtgärd

Eftersom WIF redan är implementerat bör den gamla långlivade nyckeln inte längre behövas och bör revokeras/tas bort efter verifiering.

#### Bevis / resultat

> Fylls i efter verifiering.

---

# 🟠 Medium prioritet

### 4. GitHub Branch Protection kan inte enforceas fullt ut

**Status:** ☐ Att verifiera  
**Severity:** Medium  
**Ansvarig:** __________

#### Vad ska undersökas?

- Kontrollera reglerna på `main`.
- Kontrollera krav på Pull Request.
- Kontrollera krav på två approvals.
- Kontrollera `Format & Validate`.
- Kontrollera om reglerna faktiskt enforceas.
- Dokumentera begränsningen som beror på GitHub-planen.

#### Risk

Om branch protection inte kan enforceas fullt ut finns risk att skyddsregler kan kringgås.

#### Rekommenderad åtgärd

Använd en GitHub-plan/funktionalitet som stödjer den önskade enforcement-nivån eller komplettera med andra skydd.

#### Bevis / resultat

> Fylls i efter verifiering.

---

### 5. SSH Key Management och fingerprint-verifiering

**Status:** ☐ Att verifiera  
**Severity:** Medium  
**Ansvarig:** __________

#### Vad ska undersökas?

- Kontrollera SSH-nycklar i `ssh_users`.
- Kontrollera `authorized_keys`.
- Kontrollera fingerprints.
- Kontrollera om gamla nycklar finns kvar.
- Kontrollera processen för att lägga till nya användare.
- Kontrollera processen för att ta bort användare.

#### Observation

Ett SSH-problem upptäcktes där en public key såg korrekt ut som text men hade ett annat fingerprint än den klienten faktiskt erbjöd.

#### Risk

Om public keys överförs eller verifieras enbart genom att jämföra text kan fel nyckel användas utan att det upptäcks.

#### Rekommenderad åtgärd

Använd fingerprint-verifiering när SSH-nycklar distribueras eller felsöks.

#### Bevis / resultat

> Fylls i efter verifiering.
Samuel - Om vi stänger av funktionen nu att skapa nya fingerprints när vi vet att alla som ska har åtkomst har loggat in och skapat sina fingerprints så hade det varit ett bra defensivt lager ifall om någons public key skulle bli stulet. 
---

### 6. GCP State Bucket – åtkomst och skydd

**Status:** ☐ Att verifiera  
**Severity:** Medium  
**Ansvarig:** __________

#### Vad ska undersökas?

Kontrollera state-bucketen:

`team1-tfstate-920afb25`

Kontrollera:

- IAM-behörigheter.
- Public access.
- Encryption.
- Versioning.
- Retention.
- Vilka service accounts och användare som har åtkomst.

#### Risk

State-bucketen innehåller Terraform State och behöver därför ha strikt åtkomstkontroll.

#### Rekommenderad åtgärd

Begränsa bucketens åtkomst enligt least privilege och säkerställ att den inte är publikt åtkomlig.

#### Bevis / resultat

> Fylls i efter verifiering.

---

### 7. GitHub Actions Security

**Status:** ☐ Att verifiera  
**Severity:** Medium  
**Ansvarig:** __________

#### Vad ska undersökas?

Kontrollera `.github/workflows/`, särskilt deployment-workflow:

- Workflow permissions.
- GitHub secrets.
- GitHub variables.
- GCP-behörigheter.
- Actions-versioner.
- Om Pull Requests kan påverka deployment.
- Om workflow har större permissions än nödvändigt.

#### Risk

För breda GitHub- eller GCP-behörigheter kan öka konsekvenserna av en komprometterad workflow eller repository.

#### Rekommenderad åtgärd

Använd minimala permissions och säkerställ att deployment endast kan utföras på avsedda branches/workflows.

#### Bevis / resultat

> Fylls i efter verifiering.

---

# 🟡 Låg prioritet

### 8. Jumphost saknar vissa diagnostikverktyg

**Status:** ☐ Förbättring  
**Severity:** Low  
**Ansvarig:** __________

#### Observation

Jumphosten saknade initialt:

- `dig`
- `nc`

Verktygen installerades manuellt under felsökningen.

#### Risk

Detta är främst ett operativt problem och kan göra nätverksfelsökning långsammare.

#### Rekommenderad åtgärd

Installera nödvändiga nätverksdiagnostikverktyg automatiskt vid provisioning om de ska användas i miljön.

#### Bevis / resultat

> `dig` och `nc` behövde installeras manuellt.

---

### 9. SOCKS5 / SSH Proxy-konfiguration

**Status:** ☐ Förbättring  
**Severity:** Low  
**Ansvarig:** __________

#### Observation

SOCKS5-tunneln startades med:

`ssh -D 1080`

Port `1080` var redan upptagen och en annan port behövde användas.

#### Vad ska undersökas?

- Dokumentera hur SOCKS5-tunneln startas.
- Dokumentera vilken port som används.
- Dokumentera hur Chrome konfigureras.
- Dokumentera vad som görs om standardporten är upptagen.

#### Rekommenderad åtgärd

Lägg till en tydlig standardprocedur för proxyåtkomst till labbmiljön.

#### Bevis / resultat

> Fylls i efter verifiering.

---

### 10. Kontroll av hårdkodade secrets och känslig information

**Status:** ☐ Att verifiera  
**Severity:** Low/Medium  
**Ansvarig:** __________

#### Vad ska undersökas?

Genomsök repositoryt efter:

- Passwords.
- API keys.
- Service account keys.
- Tokens.
- Privata nycklar.
- Känsliga Terraform outputs.
- Secrets i `.tfvars`.
- Secrets i GitHub Actions.
- Secrets i Git-historiken.

#### Risk

Hårdkodade credentials kan läcka via Git, Pull Requests eller GitHub repository history.

#### Rekommenderad åtgärd

Använd GitHub Secrets, WIF eller annan lämplig secret management-lösning och ta bort credentials från versionshanterad kod.

#### Bevis / resultat

> Fylls i efter verifiering.

---

# Arbetsprocess

För varje område:

1. **Undersök**
2. **Samla bevis**
3. **Dokumentera resultat**
4. Bedöm **Severity**
5. Skapa GitHub Issue om problemet kan bekräftas
6. Lägg till rekommenderad åtgärd
7. Stäng Issue när problemet är åtgärdat

## Status

- ☐ Att verifiera
- 🔎 Under undersökning
- 🔴 Bekräftat
- 🟢 Åtgärdat
- ⚪ Ej ett problem

## Viktigt

Detta dokument ska endast innehålla sådant som kan kopplas till våra faktiska tester, konfigurationer eller observationer.

CTF-flaggor och flaggrelaterade fynd dokumenteras separat och ska inte läggas som säkerhetsissues.
