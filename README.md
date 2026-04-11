<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-40README-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

# 40ants-ai-agents - A framework for building AI agent networks in Common Lisp.

<a id="40-ants-ai-agents-asdf-system-details"></a>

## 40ANTS-AI-AGENTS ASDF System Details

* Description: A framework for building `AI` agent networks in Common Lisp.
* Licence: Unlicense
* Author: Alexander Artemenko <svetlyak.40wt@gmail.com>
* Homepage: [https://40ants.com/ai-agents/][ae69]
* Bug tracker: [https://github.com/40ants/ai-agents/issues][8059]
* Source control: [GIT][b834]
* Depends on: [completions][26ac], [serapeum][c41d]

[![](https://github-actions.40ants.com/40ants/ai-agents/matrix.svg?only=ci.run-tests)][e1ad]

![](http://quickdocs.org/badge/40ants-ai-agents.svg)

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-40INSTALLATION-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## Installation

You can install this library from Quicklisp, but you want to receive updates quickly, then install it from Ultralisp.org:

```
(ql-dist:install-dist "http://dist.ultralisp.org/"
                      :prompt nil)
(ql:quickload :40ants-ai-agents)
```
<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-40USAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## Usage

`TODO`: Write a library description. Put some examples here.

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-40API-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## API

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FAI-AGENT-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/AI-AGENT

<a id="x-28-23A-28-2825-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FAI-AGENT-22-29-20PACKAGE-29"></a>

#### [package](ad6a) `40ants-ai-agents/ai-agent`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FAI-AGENT-3FClasses-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Classes

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FAI-AGENT-24AI-AGENT-3FCLASS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

##### AI-AGENT

<a id="x-2840ANTS-AI-AGENTS-2FAI-AGENT-3AAI-AGENT-20CLASS-29"></a>

###### [class](61f5) `40ants-ai-agents/ai-agent:ai-agent` ()

**Readers**

<a id="x-2840ANTS-AI-AGENTS-2FAI-AGENT-3AAGENT-COMPLETER-20-2840ANTS-DOC-2FLOCATIVES-3AREADER-2040ANTS-AI-AGENTS-2FAI-AGENT-3AAI-AGENT-29-29"></a>

###### [reader](73bc) `40ants-ai-agents/ai-agent:agent-completer` (ai-agent) (:completer)

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FAI-AGENT-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-AGENTS-2FAI-AGENT-3AAI-AGENT-20FUNCTION-29"></a>

##### [function](3542) `40ants-ai-agents/ai-agent:ai-agent` PROMPT &KEY TOOLS (MODEL "deepseek-chat") ENDPOINT

Create an `AI` agent with the given system `PROMPT` and optional `TOOLS` list.
`MODEL` selects the `LLM` model (default: "deepseek-chat").
`ENDPOINT` overrides the `API` `URL`; when nil the default for `MODEL` is used.

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FAI-MESSAGE-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/AI-MESSAGE

<a id="x-28-23A-28-2827-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FAI-MESSAGE-22-29-20PACKAGE-29"></a>

#### [package](4f70) `40ants-ai-agents/ai-message`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FAI-MESSAGE-3FClasses-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Classes

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FAI-MESSAGE-24AI-MESSAGE-3FCLASS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

##### AI-MESSAGE

<a id="x-2840ANTS-AI-AGENTS-2FAI-MESSAGE-3AAI-MESSAGE-20CLASS-29"></a>

###### [class](b08a) `40ants-ai-agents/ai-message:ai-message` (message)

**Readers**

<a id="x-2840ANTS-AI-AGENTS-2FAI-MESSAGE-3AAI-MESSAGE-TEXT-20-2840ANTS-DOC-2FLOCATIVES-3AREADER-2040ANTS-AI-AGENTS-2FAI-MESSAGE-3AAI-MESSAGE-29-29"></a>

###### [reader](1fd1) `40ants-ai-agents/ai-message:ai-message-text` (ai-message) (:text)

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FAI-MESSAGE-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-AGENTS-2FAI-MESSAGE-3AAI-MESSAGE-20FUNCTION-29"></a>

##### [function](02c8) `40ants-ai-agents/ai-message:ai-message` text

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FGENERICS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/GENERICS

<a id="x-28-23A-28-2825-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FGENERICS-22-29-20PACKAGE-29"></a>

#### [package](e76f) `40ants-ai-agents/generics`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FGENERICS-3FGenerics-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Generics

<a id="x-2840ANTS-AI-AGENTS-2FGENERICS-3AADD-MESSAGE-20GENERIC-FUNCTION-29"></a>

##### [generic-function](11ef) `40ants-ai-agents/generics:add-message` state message

Adds a message to the state and returns the new state object.

<a id="x-2840ANTS-AI-AGENTS-2FGENERICS-3APROCESS-20GENERIC-FUNCTION-29"></a>

##### [generic-function](dce0) `40ants-ai-agents/generics:process` agent state

Processing state by the agent.

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FMESSAGE-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/MESSAGE

<a id="x-28-23A-28-2824-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FMESSAGE-22-29-20PACKAGE-29"></a>

#### [package](8a57) `40ants-ai-agents/message`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FMESSAGE-3FClasses-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Classes

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FMESSAGE-24MESSAGE-3FCLASS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

##### MESSAGE

<a id="x-2840ANTS-AI-AGENTS-2FMESSAGE-3AMESSAGE-20CLASS-29"></a>

###### [class](6594) `40ants-ai-agents/message:message` ()

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FSTATE-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/STATE

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FSTATE-22-29-20PACKAGE-29"></a>

#### [package](9eb3) `40ants-ai-agents/state`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FSTATE-3FClasses-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Classes

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FSTATE-24STATE-3FCLASS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

##### STATE

<a id="x-2840ANTS-AI-AGENTS-2FSTATE-3ASTATE-20CLASS-29"></a>

###### [class](e3fb) `40ants-ai-agents/state:state` ()

**Readers**

<a id="x-2840ANTS-AI-AGENTS-2FSTATE-3ASTATE-MESSAGES-20-2840ANTS-DOC-2FLOCATIVES-3AREADER-2040ANTS-AI-AGENTS-2FSTATE-3ASTATE-29-29"></a>

###### [reader](778b) `40ants-ai-agents/state:state-messages` (state) (:messages = nil)

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FSTATE-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-AGENTS-2FSTATE-3ASTATE-20FUNCTION-29"></a>

##### [function](ae02) `40ants-ai-agents/state:state` messages

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FUSER-MESSAGE-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/USER-MESSAGE

<a id="x-28-23A-28-2829-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FUSER-MESSAGE-22-29-20PACKAGE-29"></a>

#### [package](0fa4) `40ants-ai-agents/user-message`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FUSER-MESSAGE-3FClasses-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Classes

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FUSER-MESSAGE-24USER-MESSAGE-3FCLASS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

##### USER-MESSAGE

<a id="x-2840ANTS-AI-AGENTS-2FUSER-MESSAGE-3AUSER-MESSAGE-20CLASS-29"></a>

###### [class](0e11) `40ants-ai-agents/user-message:user-message` (message)

**Readers**

<a id="x-2840ANTS-AI-AGENTS-2FUSER-MESSAGE-3AUSER-MESSAGE-TEXT-20-2840ANTS-DOC-2FLOCATIVES-3AREADER-2040ANTS-AI-AGENTS-2FUSER-MESSAGE-3AUSER-MESSAGE-29-29"></a>

###### [reader](e474) `40ants-ai-agents/user-message:user-message-text` (user-message) (:text)

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FUSER-MESSAGE-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-AGENTS-2FUSER-MESSAGE-3AUSER-MESSAGE-20FUNCTION-29"></a>

##### [function](f8d5) `40ants-ai-agents/user-message:user-message` text

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-AGENTS-2FVARS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-AGENTS/VARS

<a id="x-28-23A-28-2821-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-AGENTS-2FVARS-22-29-20PACKAGE-29"></a>

#### [package](dfb0) `40ants-ai-agents/vars`

<a id="x-2840ANTS-AI-AGENTS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-AGENTS-2FVARS-3FVariables-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Variables

<a id="x-2840ANTS-AI-AGENTS-2FVARS-3A-2AAPI-KEY-2A-20-28VARIABLE-29-29"></a>

##### [variable](fd03) `40ants-ai-agents/vars:*api-key*` -unbound-

Set this token to use `AI`.


[ae69]: https://40ants.com/ai-agents/
[b834]: https://github.com/40ants/ai-agents
[e1ad]: https://github.com/40ants/ai-agents/actions
[ad6a]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-agent.lisp#L1
[61f5]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-agent.lisp#L25
[73bc]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-agent.lisp#L26
[3542]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-agent.lisp#L58
[4f70]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-message.lisp#L1
[b08a]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-message.lisp#L10
[1fd1]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-message.lisp#L11
[02c8]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/ai-message.lisp#L16
[e76f]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/generics.lisp#L1
[11ef]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/generics.lisp#L12
[dce0]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/generics.lisp#L8
[8a57]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/message.lisp#L1
[6594]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/message.lisp#L7
[9eb3]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/state.lisp#L1
[e3fb]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/state.lisp#L15
[778b]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/state.lisp#L16
[ae02]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/state.lisp#L24
[0fa4]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/user-message.lisp#L1
[0e11]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/user-message.lisp#L10
[e474]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/user-message.lisp#L11
[f8d5]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/user-message.lisp#L16
[dfb0]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/vars.lisp#L1
[fd03]: https://github.com/40ants/ai-agents/blob/87ffc7c2267fbb36fadf5e70ba91b112cd39183a/src/vars.lisp#L9
[8059]: https://github.com/40ants/ai-agents/issues
[26ac]: https://quickdocs.org/completions
[c41d]: https://quickdocs.org/serapeum

* * *
###### [generated by [40ANTS-DOC](https://40ants.com/doc/)]
