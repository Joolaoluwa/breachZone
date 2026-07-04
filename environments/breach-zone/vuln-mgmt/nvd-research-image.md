# D4 - NVD RESEARCH - TOP 5 CRITICAL CVEs (IMAGE DOCKER)

## 1. CVE-2025-14087
- **Source**: Image Docker (`trivy-image-scan.txt`)
- **Package**: GLib (Gnome Lib) 
- **Affected Version**:3.x 
- **Fix Version**: 4.0
- **CVSS Score**: 9.8 (NVD)
- **Description**: A flaw was found in GLib (Gnome Lib). This vulnerability allows a remote attacker to cause heap corruption, leading to a denial of service or potential code execution via a buffer-underflow in the GVariant parser when processing maliciously crafted input strings.
- **Reachability Assessment**: GLib is a system dependency. The application does not use GVariant directly.
- **Status**: [ ] Patched / [ ] Compensating Control
- **Action**: Risk accepted – package used solely as a dependency; no critical functionality exposed.

---
## 2. CVE-2026-22770
- **Source**: Image Docker (`trivy-image-scan.txt`)
- **Package**: imagemagick
- **Affected Version**: 8:7.1.1.43+dfsg1-1+deb13u2
- **Fix Version**: 8:7.1.1.43+dfsg1-1+deb13u5
- **CVSS Score**: 9.8 (CRITICAL)
- **Description**: ImageMagick: Denial of Service due to improper validation
- **Reachability Assessment**: The application uses ImageMagick for image processing.
- **Patch Evidence**: https://github.com/ImageMagick/ImageMagick/commit/xxxx
- **Status**: [x] Patched / [ ] Compensating Control
- **Action**: Update to the fixed version (deb13u5)
---

## 3. CVE-2026-31789
- **Source**: Docker Image (`trivy-image-scan.txt`)
- **Package**: libssl-dev (OpenSSL)
- **Affected Version**: 3.5.1-1+deb13u1
- **Fix Version**: 3.5.5-1~deb13u2
- **CVSS Score**: 9.8
- **Description**: Heap buffer overflow in OpenSSL on 32-bit systems, potentially leading to remote code execution or denial of service.
- **Reachability Assessment**:
  - The application uses OpenSSL for secure communications (HTTPS, TLS)
  - The package is critical for network security
  - The target architecture is likely 64-bit, which reduces the impact
- **Patch Evidence**: Fixed in version 3.5.5-1~deb13u2
- **Status**: [x] Patched / [ ] Compensating Control
- **Action**: Update OpenSSL to version 3.5.5-1~deb13u2
---

## 4. CVE-2026-33845
- **Source**: Docker Image (`trivy-image-scan.txt`)
- **Package**: libgnutls-dane0t64 (GnuTLS)
- **Affected Version**: 3.8.9-3
- **Fix Version**: 3.8.9-3+deb13u4
- **CVSS Score**: 9.1
- **Description**: Denial of Service vulnerability in GnuTLS via DTLS zero-length handshake messages, allowing remote attackers to crash the service.
- **Reachability Assessment**: 
  - The application uses TLS/SSL for secure communications
  - GnuTLS is a core system library used by many applications
  - The vulnerability specifically affects DTLS (Datagram TLS), which may not be used
- **Patch Evidence**: Fixed in version 3.8.9-3+deb13u4
- **Status**: [x] Patched / [ ] Compensating Control
- **Action**: Update GnuTLS to version 3.8.9-3+deb13u4

---

## 5. CVE-2026-42496
- **Source**: Docker Image
- **Package**: libperl5.40 (perl-archive-tar)
- **Affected Version**: 5.40.1-6
- **Fix Version**: Not available (fix_deferred)
- **CVSS Score**: 9.1 (HIGH) 
- **Description**: Path traversal in perl-archive-tar allowing file write outside the target directory.
- **Reachability Assessment**: The application uses Perl but does not directly use Archive::Tar.
- **Patch Evidence**: No fix available at this time.
- **Status**: [ ] Patched / [x] Compensating Control
- **Action**: Risk Accepted – package not directly used
## References
- https://nvd.nist.gov/vuln/detail/CVE-2026-XXXXX
