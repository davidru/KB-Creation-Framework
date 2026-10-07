# Third-Party Open-Source Notices
## crawl4ai-fetch Adapter (KB Creation Framework v3.0.1)

**Date:** 2026-06-06 (updated)
**Adapter:** `KB Creation - Modular v3\adapters\crawl4ai-fetch\`
**Scope:** This NOTICE file covers the six direct dependencies pinned in `requirements.txt` plus their material runtime dependencies that ship binaries (browser engines, certificate bundles). Transitive Python-package dependencies are subject to their own licenses; consult `pip show <package>` or each project's PyPI page for full chains.

This file exists to satisfy the attribution and source-disclosure obligations imposed by the upstream open-source licenses. The KB Creation Framework's `Extract-AuthorityView.ps1`, `Register-Lint.ps1`, `Verbatim-Linter.ps1`, and all other PowerShell scripts in the framework root are original works not subject to these third-party licenses.

### Change history note: nodriver → patchright in v3.0.1

The earlier v3.0.0 build of this adapter included `nodriver` (AGPL-3.0) as the Tier-3 Cloudflare-interactive-challenge fallback. AGPL-3.0 is incompatible with the framework's intended distribution model, so on 2026-06-06 `nodriver` was replaced with `patchright` (Apache-2.0; Copyright 2024 Vinyzu; https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python), a Playwright fork with anti-detection patches that provides equivalent Cloudflare-interactive-challenge bypass under a permissive license. The four-tier fetch cascade is preserved (Crawl4AI → PDF fallback → patchright → Scrapling Turnstile); only the Tier-3 implementation library changed.

---

## Summary Table

| Project | Version pin (requirements.txt) | License | Copyright | Source |
|---|---|---|---|---|
| `crawl4ai` | `==0.8.6` | Apache-2.0 with additional attribution requirement | UncleCode and Crawl4AI contributors | https://github.com/unclecode/crawl4ai |
| `playwright` | `==1.47.0` | Apache-2.0 | Portions Microsoft Corporation; Portions 2017 Google Inc. | https://github.com/microsoft/playwright-python |
| `patchright` | `>=1.47.0` | Apache-2.0 | © 2024 Vinyzu | https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python |
| `httpx` | `==0.27.2` | BSD-3-Clause | © 2019 Encode OSS Ltd | https://github.com/encode/httpx |
| `pypdf` | `==4.3.1` | BSD-3-Clause (with author-attribution variant) | © 2006-2008 Mathieu Fenniak; © 2007 Ashish Kulkarni; © 2014 Steve Witham | https://github.com/py-pdf/pypdf |
| `scrapling[fetchers]` | `>=0.3.0` | BSD-3-Clause | © 2024 Karim shoair | https://github.com/D4Vinci/Scrapling |

**Transitive binary distributions:**
- `crawl4ai-setup`, `playwright install chromium`, and `patchright install chromium` each download Chromium browser binaries (BSD-3-Clause + LGPL components; see https://www.chromium.org/chromium-os/licensing/ for the comprehensive Chromium license list). The `patchright` build is a patched Chromium with anti-detection modifications applied.
- `certifi` (pulled in transitively as a TLS-bundle provider) is MPL-2.0; the ca-certificates database it bundles is under Mozilla's separate license.

The transitive binary footprint warrants its own license-compliance review if the framework is distributed.

---

## 1. Crawl4AI (`crawl4ai==0.8.6`)

**License:** Apache License, Version 2.0, **with an additional Attribution Requirement** imposed by the upstream LICENSE file.
**Copyright holder:** UncleCode (https://x.com/unclecode) and Crawl4AI project contributors, per the upstream LICENSE and project documentation. **Not a Microsoft work.**
**Source:** https://github.com/unclecode/crawl4ai
**Upstream LICENSE file:** https://github.com/unclecode/crawl4ai/blob/main/LICENSE

### Verbatim upstream LICENSE in this directory

The full upstream Crawl4AI LICENSE — including the Apache-2.0 base text and the Attribution Requirement section — is reproduced **verbatim and byte-faithful** as the file `LICENSE` adjacent to this NOTICES file. That `LICENSE` file is the canonical location for the upstream license text. This NOTICES entry intentionally does NOT re-reproduce the full Attribution Requirement section inline (the canonical home is the adjacent `LICENSE`); however, it does carry the required attribution string for discoverability:

> "This product includes software developed by UncleCode (https://x.com/unclecode) as part of the Crawl4AI project (https://github.com/unclecode/crawl4ai)."

Provenance of the verbatim `LICENSE` file (upstream URL, blob SHA, retrieval date, re-audit obligation) is recorded in the adjacent `NOTICE-glue-code.md` § 1.

### How this adapter satisfies the upstream Attribution Requirement

The KB Creation Framework satisfies Crawl4AI's Attribution Requirement by reproducing the attribution string in **three** locations that fall within the upstream LICENSE's enumerated acceptable-locations list:

1. The adjacent `LICENSE` file — verbatim reproduction of the entire upstream Attribution Requirement section.
2. The adapter's `README.md` (Attribution section near the top) — required prominent README location.
3. This NOTICES file (above) — additional location for redundancy and discoverability.

Any redistribution of this adapter MUST continue to display the attribution string in at least one of the locations enumerated in the upstream LICENSE (NOTICE file, README, About/Credits, or CLI help output).

### Apache-2.0 license text

The Apache-2.0 license text governing Crawl4AI is reproduced verbatim in the adjacent `LICENSE` file (alongside the Attribution Requirement section). The same Apache-2.0 boilerplate is also reproduced in § 2 below (Playwright Python) for reference. The canonical Apache-2.0 text is at https://www.apache.org/licenses/LICENSE-2.0.

---

## 2. Playwright Python (`playwright==1.47.0`)

**License:** Apache License, Version 2.0.
**Copyright:** Portions Copyright (c) Microsoft Corporation. Portions Copyright 2017 Google Inc.
**Source:** https://github.com/microsoft/playwright-python

### Apache-2.0 license text (verbatim, applies to both Playwright Python and Crawl4AI)

```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Portions Copyright (c) Microsoft Corporation.
   Portions Copyright 2017 Google Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

---

## 3. HTTPX (`httpx==0.27.2`)

**License:** BSD-3-Clause.
**Copyright:** © 2019 Encode OSS Ltd. All rights reserved.
**Source:** https://github.com/encode/httpx

### Verbatim license text

```
Copyright © 2019, Encode OSS Ltd (https://www.encode.io/).
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its contributors
  may be used to endorse or promote products derived from this software
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

---

## 4. pypdf (`pypdf==4.3.1`)

**License:** BSD-3-Clause (with author-attribution variant — the "name of the author" rather than "name of the copyright holder nor the names of its contributors" wording).
**Copyright:** © 2006-2008 Mathieu Fenniak. Some contributions © 2007 Ashish Kulkarni. Some contributions © 2014 Steve Witham.
**Source:** https://github.com/py-pdf/pypdf

### Verbatim license text

```
Copyright (c) 2006-2008, Mathieu Fenniak
Some contributions copyright (c) 2007, Ashish Kulkarni <kulkarni.ashish@gmail.com>
Some contributions copyright (c) 2014, Steve Witham <switham_github@mac-guyver.com>

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
* The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

---

## 5. Patchright (`patchright>=1.47.0`)

**License:** Apache License, Version 2.0.
**Copyright:** Copyright 2024 Vinyzu.
**Source:** https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python

### Role in the adapter

`patchright` is a maintained fork of Playwright with anti-detection / anti-fingerprint patches applied to the bundled Chromium. The adapter's Tier-3 `fetch_cf_fallback.py` uses patchright's `sync_playwright` API (drop-in compatible with upstream Playwright) to drive a non-headless patched Chromium past Cloudflare's interactive-challenge gate. It replaced `nodriver` in v3.0.1 because nodriver is AGPL-3.0; patchright is Apache-2.0 and provides equivalent functionality under the same permissive license as Playwright upstream.

### Apache-2.0 license text

Apache-2.0 license text is reproduced verbatim in § 2 above (Playwright Python). It applies equally to patchright.

The patchright upstream LICENSE is available at: https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python/blob/main/LICENSE.md

### Attribution

Patchright's NOTICE / README requires that distributions clearly attribute the project. The summary table above and this entry satisfy that requirement.

---

## 6. Scrapling (`scrapling[fetchers]>=0.3.0`)

**License:** BSD-3-Clause.
**Copyright:** © 2024 Karim shoair.
**Source:** https://github.com/D4Vinci/Scrapling

### Verbatim license text

```
BSD 3-Clause License

Copyright (c) 2024, Karim shoair

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

## Transitive Dependencies — Material Cases

### Chromium binaries (downloaded by `playwright install chromium` and `patchright install chromium`)

Chromium is BSD-3-Clause for its own code with a large transitive license footprint including (non-exhaustive): LGPL-2.1, MPL-2.0, Apache-2.0, MIT, ISC. The comprehensive license list lives at https://www.chromium.org/chromium-os/licensing/. The KB Creation Framework does not redistribute Chromium binaries; they are downloaded by upstream tooling at install time and remain under their respective licenses on the operator's machine. Operators distributing the framework should NOT bundle the Chromium binaries; the install commands should re-run on each machine.

### `certifi` (transitive via httpx + crawl4ai)

Mozilla Public License 2.0 for the Python package. The bundled ca-certificates database is under Mozilla's separate license (MPL/copyright variant). Note: Microsoft's Purview DLP rules flag `.pem` files matching the bundled `cacert.pem`; the framework's adapter README documents the workaround (place venv outside OneDrive).

---

## Microsoft Internal OSS Use Process — Operator Responsibilities

This NOTICE file satisfies the upstream open-source license requirements for attribution and reproduction of the license text. It does NOT, by itself, satisfy Microsoft's internal OSS Use Process.

The operator is responsible for:

- Verifying that each direct dependency (and any material transitive) is approved per Microsoft's OSS Use Process.
- Tracking dependency version upgrades (the version pins in `requirements.txt`); license terms can change between versions, and an upgrade to a new major version may introduce license changes that require re-review.
- For any redistribution scenario (open-sourcing the framework, internal distribution within a Microsoft business unit, or external distribution): performing a fresh license-compatibility review with current OSPO and CELA guidance.

This NOTICE file should be updated whenever:
1. A direct dependency in `requirements.txt` is added, removed, version-pinned, or replaced.
2. A transitive dependency's license is verified or changes.
3. The upstream license of any pinned dependency changes (e.g., the upstream project re-licenses).

---

## Update History

| Date | Change | By |
|---|---|---|
| 2026-06-06 | **Crawl4AI license restructure.** The adapter's `LICENSE.txt` (which incorrectly led with "Copyright (c) Microsoft Corporation" in a directory built around Crawl4AI) was deleted. Replaced with `LICENSE` reproducing the upstream Crawl4AI LICENSE byte-faithfully (blob SHA `ade44a78…`), with zero Microsoft mention in that file. Added `NOTICE-glue-code.md` documenting the MIT inheritance for the Microsoft-authored Python glue scripts (parent v3 `LICENSE.txt`). Parent v3 `LICENSE.txt` scope clause tightened to explicitly cover adapter glue code by name. Parent pointer `KB Creation Framework\LICENSE.txt` updated to reflect the new adapter license arrangement. NOTICES § 1 narrative refactored to point at the adjacent `LICENSE` as canonical home for the verbatim Attribution Requirement text (NOTICES still carries the attribution string for discoverability). Adapter README Attribution section updated to attribute UncleCode explicitly and link the new `LICENSE` + `NOTICE-glue-code.md` files. UncleCode's name is no longer displaced by Microsoft anywhere in the adapter directory. | Copilot CLI |
| 2026-06-06 | **Crawl4AI attribution strengthened.** NOTICES § 1 now reproduces the full upstream Attribution Requirement section verbatim from `https://github.com/unclecode/crawl4ai/blob/main/LICENSE` (not just the attribution string), explicitly anchors the copyright to UncleCode and Crawl4AI contributors, and enumerates the three locations where this adapter satisfies the upstream's display requirement. Adapter README gained a top-level "Attribution" section reproducing the attribution string verbatim. Adapter LICENSE.txt was expanded to enumerate the Apache-2.0 + Attribution Requirement combination for Crawl4AI specifically. (Superseded same day by the Crawl4AI license restructure entry above, which moved the verbatim Attribution Requirement reproduction to the new sibling `LICENSE` file and deleted the LICENSE.txt that opened with Microsoft copyright.) | Copilot CLI |
| 2026-06-06 | Initial NOTICE file. All six direct dependency licenses retrieved verbatim from upstream GitHub repos and reproduced or canonically referenced. AGPL-3.0 flag on nodriver surfaced as a separate compatibility notice. | Copilot CLI (framework v3.0 build) |
| 2026-06-06 | **nodriver → patchright.** AGPL-3.0 incompatibility led to replacing the Tier-3 Cloudflare-interactive-challenge fallback library. `nodriver` (AGPL-3.0) removed; `patchright>=1.47.0` (Apache-2.0; © 2024 Vinyzu; https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python) added as the new Tier-3 library; `fetch_cf_fallback.py` rewritten against patchright's drop-in Playwright API; `requirements.txt` updated; adapter README and framework rulebooks/prompts updated. Six direct dependencies (patchright now direct, was previously transitive via Scrapling). Four-tier cascade preserved. Framework version bumped to v3.0.1. | Copilot CLI |

---

*End of THIRD_PARTY_NOTICES.md for the crawl4ai-fetch adapter. For framework-level OSS attribution (other adapters added in the future), see `KB Creation - Modular v3\THIRD_PARTY_NOTICES.md` if present, or aggregate per-adapter NOTICE files at the framework root before redistribution.*
