# Third-Party Licenses

This document lists the licenses of the dependencies used in Qwen Code Web UI.

## Overview

Qwen Code Web UI uses open-source software from various sources. This document provides attribution to the open-source projects we depend on.

## License Summary

| License | Count | Description |
|---------|-------|-------------|
| MIT | ~200+ | Permissive license allowing reuse with attribution |
| Apache-2.0 | ~20+ | Permissive license with patent grant |
| ISC | ~15+ | Simple permissive license |
| BSD-3-Clause | ~5+ | Permissive license with attribution |
| BSD-2-Clause | ~2+ | Simplified BSD license |
| BlueOak-1.0.0 | ~3+ | Modern permissive license |

## Key Dependencies by License

### MIT License

The following key dependencies are licensed under MIT:

| Package | Author/Organization | Purpose |
|---------|---------------------|---------|
| react | Meta | UI framework |
| react-dom | Meta | React DOM rendering |
| react-router-dom | Remix Software | Client-side routing |
| hono | Yusuke Wada | Web framework |
| @hono/node-server | Yusuke Wada | Node.js server adapter |
| vite | Evan You | Build tool |
| vitest | Anthony Fu | Testing framework |
| esbuild | Evan Wallace | JavaScript bundler |
| prettier | James Long | Code formatter |
| eslint | Nicholas C. Zakas | Linter |
| @heroicons/react | Tailwind Labs | Icon library |
| tailwindcss | Tailwind Labs | CSS framework |
| dayjs | iamkun | Date library |
| zod | Colin McDonnell | Schema validation |
| @logtape/logtape | Hong Minhee | Logging library |
| commander | Tian You | CLI framework |

### Apache License 2.0

The following key dependencies are licensed under Apache-2.0:

| Package | Author/Organization | Purpose |
|---------|---------------------|---------|
| @qwen-code/sdk | Alibaba/Qwen Team | Qwen Code SDK |
| @qwen-code/webui | Alibaba/Qwen Team | Qwen Code WebUI components |
| typescript | Microsoft | TypeScript compiler |
| @modelcontextprotocol/sdk | Anthropic | MCP SDK |
| playwright | Microsoft | Browser automation |
| @eslint/config-array | Nicholas C. Zakas | ESLint configuration |
| @eslint/core | Nicholas C. Zakas | ESLint core |

### ISC License

The following dependencies are licensed under ISC:

| Package | Author | Purpose |
|---------|--------|---------|
| semver | GitHub Inc. | Semantic versioning |
| rimraf | Isaac Z. Schlueter | File removal |
| minimatch | Isaac Z. Schlueter | Pattern matching |
| which | Isaac Z. Schlueter | Executable finder |
| signal-exit | Ben Coe | Signal handling |

### BSD Licenses

| Package | License | Author | Purpose |
|---------|---------|--------|---------|
| qs | BSD-3-Clause | Jordan Harband | Query string parser |
| source-map-js | BSD-3-Clause | Valentin Semirulnik | Source map library |
| tough-cookie | BSD-3-Clause | Salesforce | Cookie jar |
| uri-js | BSD-2-Clause | Gary Court | URI parser |
| webidl-conversions | BSD-2-Clause | Domenic Denicola | WebIDL conversions |

### BlueOak-1.0.0 License

| Package | Author | Purpose |
|---------|--------|---------|
| package-json-from-dist | Isaac Z. Schlueter | Package.json resolver |
| path-scurry | Isaac Z. Schlueter | Path handling |
| yallist | Isaac Z. Schlueter | Linked list |

## Full License Texts

### MIT License

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Apache License 2.0

```
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

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

### ISC License

```
ISC License

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

### BSD 3-Clause License

```
BSD 3-Clause License

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

### BSD 2-Clause License

```
BSD 2-Clause License

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

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

## Notes

- This list is auto-generated using `license-checker` and may not be exhaustive
- For the most up-to-date license information, check each package's LICENSE file
- Some packages may have multiple licenses; the most permissive is typically listed
- This document should be updated when dependencies are added or updated

---

*Last updated: 2026-03-16*