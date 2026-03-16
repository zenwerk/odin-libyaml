# odin-libyaml API リファレンス

[libyaml](https://pyyaml.org/wiki/LibYAML) 0.2.5 の Odin バインディング — YAML のパースと出力を行う C ライブラリ。

パッケージ名: `yaml`

```odin
import yaml "path/to/odin-libyaml"
```

## 目次

- [ビルド設定](#ビルド設定)
- [バージョン](#バージョン)
- [基本型](#基本型)
- [スキャナ (トークナイザ)](#スキャナ-トークナイザ)
- [パーサ (イベントベース)](#パーサ-イベントベース)
- [ローダ (ドキュメント API)](#ローダ-ドキュメント-api)
- [エミッタ (イベントベース出力)](#エミッタ-イベントベース出力)
- [ダンパ (ドキュメントベース出力)](#ダンパ-ドキュメントベース出力)
- [エラー処理](#エラー処理)
- [高レベル Unmarshal API](#高レベル-unmarshal-api)
- [カスタムデコーダ](#カスタムデコーダ)

---

## ビルド設定

デフォルトでは静的ライブラリにリンクされる。共有ライブラリを使用する場合は `LIBYAML_SHARED` を設定する:

```odin
import yaml "odin-libyaml" // 静的リンク (デフォルト)
```

```sh
# 共有ライブラリを使用する場合
odin run . -define:LIBYAML_SHARED=true
```

ライブラリファイルの配置先:
- macOS: `macos/libyaml.a` (静的) または `macos/libyaml.dylib` (共有)
- Windows: `windows/libyaml.lib` (静的) または `windows/libyaml.dll` (共有)

---

## バージョン

### `get_version_string`

libyaml のバージョンを C 文字列として返す。

```
get_version_string :: proc() -> cstring
```

**戻り値:** null 終端のバージョン文字列 (例: `"0.2.5"`)。

### `get_version`

バージョン番号を major/minor/patch の整数として取得する。

```
get_version :: proc(major: ^c.int, minor: ^c.int, patch: ^c.int)
```

| パラメータ | 型 | 説明 |
|-----------|------|-------------|
| `major` | `^c.int` | メジャーバージョン番号を受け取る |
| `minor` | `^c.int` | マイナーバージョン番号を受け取る |
| `patch` | `^c.int` | パッチバージョン番号を受け取る |

**サンプルコード:**

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
    fmt.printfln("libyaml %s", yaml.get_version_string())

    major, minor, patch: c.int
    yaml.get_version(&major, &minor, &patch)
    fmt.printfln("%d.%d.%d", major, minor, patch)
}
```

**出力:**

```
libyaml 0.2.5
0.2.5
```

---

## 基本型

### `char_t`

```
char_t :: c.uchar
```

libyaml が YAML コンテンツ (UTF-8 エンコード) に使用するバイト型。

### `encoding_t`

文字エンコーディング。

```
encoding_t :: enum c.int {
    ANY_ENCODING     = 0,  // 自動検出
    UTF8_ENCODING    = 1,
    UTF16LE_ENCODING = 2,
    UTF16BE_ENCODING = 3,
}
```

### `break_t`

エミッタの改行スタイル。

```
break_t :: enum c.int {
    ANY_BREAK  = 0,  // 自動選択
    CR_BREAK   = 1,  // \r
    LN_BREAK   = 2,  // \n
    CRLN_BREAK = 3,  // \r\n
}
```

### `error_type_t`

エラー種別。

```
error_type_t :: enum c.int {
    NO_ERROR       = 0,  // エラーなし
    MEMORY_ERROR   = 1,  // メモリ確保失敗
    READER_ERROR   = 2,  // 入力読み取りエラーまたは不正なエンコーディング
    SCANNER_ERROR  = 3,  // 不正なトークン
    PARSER_ERROR   = 4,  // 不正な YAML 構造
    COMPOSER_ERROR = 5,  // 不正なドキュメント構造 (例: 未定義のエイリアス)
    WRITER_ERROR   = 6,  // 出力書き込みエラー
    EMITTER_ERROR  = 7,  // エミッタへの不正なイベント列
}
```

### `mark_t`

YAML 入力における位置情報。

```
mark_t :: struct {
    index:  c.size_t,  // 先頭からのバイトオフセット
    line:   c.size_t,  // 行番号 (0始まり)
    column: c.size_t,  // 列番号 (0始まり)
}
```

### `version_directive_t`

YAML バージョンディレクティブ (`%YAML 1.1` 等)。

```
version_directive_t :: struct {
    major: c.int,
    minor: c.int,
}
```

### `tag_directive_t`

YAML タグディレクティブ (`%TAG` 等)。

```
tag_directive_t :: struct {
    handle: [^]char_t,
    prefix: [^]char_t,
}
```

### スタイル列挙型

```
scalar_style_t :: enum c.int {
    ANY_SCALAR_STYLE           = 0,  // 自動選択
    PLAIN_SCALAR_STYLE         = 1,  // プレーン: value
    SINGLE_QUOTED_SCALAR_STYLE = 2,  // シングルクォート: 'value'
    DOUBLE_QUOTED_SCALAR_STYLE = 3,  // ダブルクォート: "value"
    LITERAL_SCALAR_STYLE       = 4,  // リテラルブロック: |
    FOLDED_SCALAR_STYLE        = 5,  // 折りたたみブロック: >
}

sequence_style_t :: enum c.int {
    ANY_SEQUENCE_STYLE   = 0,  // 自動選択
    BLOCK_SEQUENCE_STYLE = 1,  // ブロック形式: - item
    FLOW_SEQUENCE_STYLE  = 2,  // フロー形式: [item, item]
}

mapping_style_t :: enum c.int {
    ANY_MAPPING_STYLE   = 0,  // 自動選択
    BLOCK_MAPPING_STYLE = 1,  // ブロック形式: key: value
    FLOW_MAPPING_STYLE  = 2,  // フロー形式: {key: value}
}
```

---

## スキャナ (トークナイザ)

スキャナは YAML 入力をトークンに分解する。最も低レベルのパースAPI。

### トークン型

```
token_type_t :: enum c.int {
    NO_TOKEN,                    // トークンなし
    STREAM_START_TOKEN,          // ストリーム開始
    STREAM_END_TOKEN,            // ストリーム終了
    VERSION_DIRECTIVE_TOKEN,     // %YAML ディレクティブ
    TAG_DIRECTIVE_TOKEN,         // %TAG ディレクティブ
    DOCUMENT_START_TOKEN,        // ---
    DOCUMENT_END_TOKEN,          // ...
    BLOCK_SEQUENCE_START_TOKEN,  // ブロックシーケンスの開始
    BLOCK_MAPPING_START_TOKEN,   // ブロックマッピングの開始
    BLOCK_END_TOKEN,             // ブロックの終了
    FLOW_SEQUENCE_START_TOKEN,   // [
    FLOW_SEQUENCE_END_TOKEN,     // ]
    FLOW_MAPPING_START_TOKEN,    // {
    FLOW_MAPPING_END_TOKEN,      // }
    BLOCK_ENTRY_TOKEN,           // -
    FLOW_ENTRY_TOKEN,            // ,
    KEY_TOKEN,                   // キー指示子
    VALUE_TOKEN,                 // 値指示子 (:)
    ALIAS_TOKEN,                 // *alias
    ANCHOR_TOKEN,                // &anchor
    TAG_TOKEN,                   // !tag
    SCALAR_TOKEN,                // スカラー値
}
```

### `token_t`

```
token_t :: struct {
    type: token_type_t,
    data: struct #raw_union {
        stream_start: struct { encoding: encoding_t },
        alias:        struct { value: [^]char_t },
        anchor:       struct { value: [^]char_t },
        tag:          struct { handle: [^]char_t, suffix: [^]char_t },
        scalar:       struct { value: [^]char_t, length: c.size_t, style: scalar_style_t },
        version_directive: struct { major: c.int, minor: c.int },
        tag_directive:     struct { handle: [^]char_t, prefix: [^]char_t },
    },
    start_mark: mark_t,
    end_mark:   mark_t,
}
```

`type` フィールドに応じて `data` 共用体の該当メンバにアクセスする。

### `parser_scan`

入力から次のトークンをスキャンする。

```
parser_scan :: proc(parser: ^parser_t, token: ^token_t) -> c.int
```

| パラメータ | 型 | 説明 |
|-----------|------|-------------|
| `parser` | `^parser_t` | 入力が設定済みの初期化されたパーサ |
| `token` | `^token_t` | スキャンされたトークンを受け取る |

**戻り値:** 成功時 `1`、エラー時 `0`。

### `token_delete`

トークンに関連するリソースを解放する。

```
token_delete :: proc(token: ^token_t)
```

### サンプル: YAML 文字列のトークン化

**入力:**

```yaml
name: Alice
age: 30
```

**コード:**

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := `name: Alice
age: 30
`
    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    token: yaml.token_t
    for {
        assert(yaml.parser_scan(&parser, &token) != 0)

        #partial switch token.type {
        case .SCALAR_TOKEN:
            value := string(token.data.scalar.value[:token.data.scalar.length])
            fmt.printfln("SCALAR \"%s\"", value)
        case .KEY_TOKEN:
            fmt.println("KEY")
        case .VALUE_TOKEN:
            fmt.println("VALUE")
        case:
            fmt.printfln("%v", token.type)
        }

        done := token.type == .STREAM_END_TOKEN
        yaml.token_delete(&token)
        if done do break
    }
}
```

**出力:**

```
STREAM_START_TOKEN
BLOCK_MAPPING_START_TOKEN
KEY
SCALAR "name"
VALUE
SCALAR "Alice"
KEY
SCALAR "age"
VALUE
SCALAR "30"
BLOCK_END_TOKEN
STREAM_END_TOKEN
```

---

## パーサ (イベントベース)

パーサは YAML の構造を表すイベントストリームを生成する。多くのユースケースで推奨される API。

### イベント型

```
event_type_t :: enum c.int {
    NO_EVENT,              // イベントなし
    STREAM_START_EVENT,    // ストリーム開始
    STREAM_END_EVENT,      // ストリーム終了
    DOCUMENT_START_EVENT,  // ドキュメント開始 (---)
    DOCUMENT_END_EVENT,    // ドキュメント終了 (...)
    ALIAS_EVENT,           // エイリアス (*anchor)
    SCALAR_EVENT,          // スカラー値
    SEQUENCE_START_EVENT,  // シーケンス開始
    SEQUENCE_END_EVENT,    // シーケンス終了
    MAPPING_START_EVENT,   // マッピング開始
    MAPPING_END_EVENT,     // マッピング終了
}
```

### `event_t`

```
event_t :: struct {
    type: event_type_t,
    data: struct #raw_union {
        stream_start:   struct { encoding: encoding_t },
        document_start: struct {
            version_directive: ^version_directive_t,
            tag_directives: struct { start, end: [^]tag_directive_t },
            implicit: c.int,
        },
        document_end: struct { implicit: c.int },
        alias:        struct { anchor: [^]char_t },
        scalar: struct {
            anchor, tag, value: [^]char_t,
            length: c.size_t,
            plain_implicit, quoted_implicit: c.int,
            style: scalar_style_t,
        },
        sequence_start: struct {
            anchor, tag: [^]char_t,
            implicit: c.int, style: sequence_style_t,
        },
        mapping_start: struct {
            anchor, tag: [^]char_t,
            implicit: c.int, style: mapping_style_t,
        },
    },
    start_mark: mark_t,
    end_mark:   mark_t,
}
```

### パーサ関数

#### `parser_initialize`

新しいパーサを作成する。使用後は必ず `parser_delete` で解放すること。

```
parser_initialize :: proc(parser: ^parser_t) -> c.int
```

**戻り値:** 成功時 `1`、失敗時 `0` (メモリ確保失敗)。

#### `parser_delete`

パーサを破棄しリソースを解放する。

```
parser_delete :: proc(parser: ^parser_t)
```

#### `parser_set_input_string`

バイト文字列をパーサの入力に設定する。

```
parser_set_input_string :: proc(parser: ^parser_t, input: [^]c.uchar, size: c.size_t)
```

| パラメータ | 型 | 説明 |
|-----------|------|-------------|
| `parser` | `^parser_t` | 初期化済みのパーサ |
| `input` | `[^]c.uchar` | UTF-8 YAML コンテンツへのポインタ |
| `size` | `c.size_t` | バイト長 |

Odin の `string` を渡す場合:

```odin
yaml.parser_set_input_string(&parser, raw_data(input), len(input))
```

#### `parser_set_input_file`

C の FILE ハンドルをパーサの入力に設定する。

```
parser_set_input_file :: proc(parser: ^parser_t, file: ^libc.FILE)
```

#### `parser_set_input`

カスタム読み取りハンドラをパーサの入力に設定する。

```
parser_set_input :: proc(parser: ^parser_t, handler: read_handler_t, data: rawptr)
```

ハンドラ型:

```
read_handler_t :: #type proc "c" (
    data: rawptr,           // ユーザデータ
    buffer: [^]c.uchar,    // 読み取り先バッファ
    size: c.size_t,         // バッファサイズ
    size_read: ^c.size_t,   // 実際に読み取ったバイト数を書き込む
) -> c.int                  // 成功時 1、エラー時 0
```

#### `parser_set_encoding`

入力エンコーディングを強制する。

```
parser_set_encoding :: proc(parser: ^parser_t, encoding: encoding_t)
```

#### `parser_parse`

入力から次のイベントをパースする。

```
parser_parse :: proc(parser: ^parser_t, event: ^event_t) -> c.int
```

**戻り値:** 成功時 `1`、エラー時 `0`。失敗時は `parser.error` と `parser.problem` を確認する。

#### `event_delete`

イベントに関連するリソースを解放する。

```
event_delete :: proc(event: ^event_t)
```

### サンプル: YAML イベントのパース

**入力:**

```yaml
server:
  host: localhost
  port: 8080
```

**コード:**

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := `server:
  host: localhost
  port: 8080
`
    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    event: yaml.event_t
    for {
        assert(yaml.parser_parse(&parser, &event) != 0)

        #partial switch event.type {
        case .SCALAR_EVENT:
            value := string(event.data.scalar.value[:event.data.scalar.length])
            fmt.printfln("SCALAR \"%s\"", value)
        case .MAPPING_START_EVENT:
            fmt.println("MAPPING-START")
        case .MAPPING_END_EVENT:
            fmt.println("MAPPING-END")
        case .DOCUMENT_START_EVENT:
            fmt.println("DOCUMENT-START")
        case .DOCUMENT_END_EVENT:
            fmt.println("DOCUMENT-END")
        case .STREAM_START_EVENT:
            fmt.println("STREAM-START")
        case .STREAM_END_EVENT:
            fmt.println("STREAM-END")
        }

        done := event.type == .STREAM_END_EVENT
        yaml.event_delete(&event)
        if done do break
    }
}
```

**出力:**

```
STREAM-START
DOCUMENT-START
MAPPING-START
SCALAR "server"
MAPPING-START
SCALAR "host"
SCALAR "localhost"
SCALAR "port"
SCALAR "8080"
MAPPING-END
MAPPING-END
DOCUMENT-END
STREAM-END
```

---

## ローダ (ドキュメント API)

ローダは YAML をメモリ上のドキュメントツリー (ノード) にパースする。YAML 構造へのランダムアクセスが必要な場合に使用する。

### ノード型

```
node_type_t :: enum c.int {
    NO_NODE       = 0,  // ノードなし
    SCALAR_NODE   = 1,  // スカラー (文字列、数値等)
    SEQUENCE_NODE = 2,  // シーケンス (配列)
    MAPPING_NODE  = 3,  // マッピング (辞書)
}
```

### `node_t`

```
node_t :: struct {
    type: node_type_t,
    tag:  [^]char_t,        // YAML タグ (例: "tag:yaml.org,2002:str")
    data: struct #raw_union {
        scalar: struct {
            value: [^]char_t,   // スカラー値
            length: c.size_t,   // バイト長
            style: scalar_style_t,
        },
        sequence: struct {
            items: struct {
                start: [^]node_item_t,  // 最初の要素へのポインタ
                end:   [^]node_item_t,  // 最後の要素の次へのポインタ
                top:   [^]node_item_t,  // 確保済み領域の終端
            },
            style: sequence_style_t,
        },
        mapping: struct {
            pairs: struct {
                start: [^]node_pair_t,  // 最初のペアへのポインタ
                end:   [^]node_pair_t,  // 最後のペアの次へのポインタ
                top:   [^]node_pair_t,  // 確保済み領域の終端
            },
            style: mapping_style_t,
        },
    },
    start_mark: mark_t,
    end_mark:   mark_t,
}
```

関連型:

```
node_item_t :: c.int          // 1始まりのノードインデックス
node_pair_t :: struct {
    key:   c.int,             // キーのノードインデックス (1始まり)
    value: c.int,             // 値のノードインデックス (1始まり)
}
```

### `document_t`

```
document_t :: struct {
    nodes: struct { start, end, top: [^]node_t },
    version_directive: ^version_directive_t,
    tag_directives: struct { start, end: [^]tag_directive_t },
    start_implicit, end_implicit: c.int,
    start_mark, end_mark: mark_t,
}
```

### ローダ関数

#### `parser_load`

パーサから次の YAML ドキュメントをロードする。

```
parser_load :: proc(parser: ^parser_t, document: ^document_t) -> c.int
```

| パラメータ | 型 | 説明 |
|-----------|------|-------------|
| `parser` | `^parser_t` | 入力が設定済みの初期化されたパーサ |
| `document` | `^document_t` | ロードされたドキュメントを受け取る |

**戻り値:** 成功時 `1`、エラー時 `0`。

#### `document_delete`

ドキュメントとすべてのノードを解放する。

```
document_delete :: proc(document: ^document_t)
```

#### `document_get_root_node`

ドキュメントのルートノードを返す。

```
document_get_root_node :: proc(document: ^document_t) -> ^node_t
```

**戻り値:** ルートノードへのポインタ。ドキュメントが空の場合は `nil`。

#### `document_get_node`

1始まりのインデックスでノードを取得する。

```
document_get_node :: proc(document: ^document_t, index: c.int) -> ^node_t
```

| パラメータ | 型 | 説明 |
|-----------|------|-------------|
| `document` | `^document_t` | ドキュメント |
| `index` | `c.int` | ノードインデックス (1始まり) |

**戻り値:** ノードへのポインタ。インデックスが無効な場合は `nil`。

### サンプル: ドキュメントをロードしてツリーを走査する

**入力:**

```yaml
fruits:
  - apple
  - banana
  - cherry
```

**コード:**

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := `fruits:
  - apple
  - banana
  - cherry
`
    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    document: yaml.document_t
    assert(yaml.parser_load(&parser, &document) != 0)
    defer yaml.document_delete(&document)

    root := yaml.document_get_root_node(&document)
    if root == nil {
        fmt.println("空のドキュメント")
        return
    }

    // ルートはマッピング — キー/値ペアを走査
    assert(root.type == .MAPPING_NODE)
    pairs := root.data.mapping.pairs
    count := (uintptr(pairs.end) - uintptr(pairs.start)) / size_of(yaml.node_pair_t)

    for i in 0 ..< count {
        pair := pairs.start[i]
        key := yaml.document_get_node(&document, pair.key)
        val := yaml.document_get_node(&document, pair.value)

        key_str := string(key.data.scalar.value[:key.data.scalar.length])
        fmt.printfln("%s:", key_str)

        // 値がシーケンスの場合 — 要素を走査
        if val.type == .SEQUENCE_NODE {
            items := val.data.sequence.items
            n := (uintptr(items.end) - uintptr(items.start)) / size_of(yaml.node_item_t)
            for j in 0 ..< n {
                child := yaml.document_get_node(&document, items.start[j])
                v := string(child.data.scalar.value[:child.data.scalar.length])
                fmt.printfln("  - %s", v)
            }
        }
    }
}
```

**出力:**

```
fruits:
  - apple
  - banana
  - cherry
```

---

## エミッタ (イベントベース出力)

エミッタはイベントストリームを YAML テキストに変換する。出力を細かく制御できる。

### エミッタ関数

#### `emitter_initialize`

新しいエミッタを作成する。使用後は必ず `emitter_delete` で解放すること。

```
emitter_initialize :: proc(emitter: ^emitter_t) -> c.int
```

**戻り値:** 成功時 `1`、失敗時 `0`。

#### `emitter_delete`

エミッタを破棄する。

```
emitter_delete :: proc(emitter: ^emitter_t)
```

#### `emitter_set_output_string`

バイトバッファをエミッタの出力先に設定する。

```
emitter_set_output_string :: proc(
    emitter: ^emitter_t,
    output: [^]c.uchar,
    size: c.size_t,
    size_written: ^c.size_t,
)
```

| パラメータ | 型 | 説明 |
|-----------|------|-------------|
| `emitter` | `^emitter_t` | 初期化済みのエミッタ |
| `output` | `[^]c.uchar` | 出力バッファ |
| `size` | `c.size_t` | バッファ容量 (バイト) |
| `size_written` | `^c.size_t` | 書き込まれたバイト数を受け取る |

Odin の配列を渡す場合:

```odin
buf: [16384]c.uchar
yaml.emitter_set_output_string(&emitter, raw_data(buf[:]), len(buf), &written)
```

#### `emitter_set_output_file`

C の FILE ハンドルをエミッタの出力先に設定する。

```
emitter_set_output_file :: proc(emitter: ^emitter_t, file: ^libc.FILE)
```

#### `emitter_set_output`

カスタム書き込みハンドラをエミッタの出力先に設定する。

```
emitter_set_output :: proc(emitter: ^emitter_t, handler: write_handler_t, data: rawptr)
```

ハンドラ型:

```
write_handler_t :: #type proc "c" (
    data: rawptr,           // ユーザデータ
    buffer: [^]c.uchar,    // 書き込むデータ
    size: c.size_t,         // データサイズ
) -> c.int                  // 成功時 1、エラー時 0
```

#### 出力オプション

```
emitter_set_encoding  :: proc(emitter: ^emitter_t, encoding: encoding_t)
emitter_set_canonical :: proc(emitter: ^emitter_t, canonical: c.int)
emitter_set_indent    :: proc(emitter: ^emitter_t, indent: c.int)
emitter_set_width     :: proc(emitter: ^emitter_t, width: c.int)
emitter_set_unicode   :: proc(emitter: ^emitter_t, unicode: c.int)
emitter_set_break     :: proc(emitter: ^emitter_t, line_break: break_t)
```

| 関数 | 説明 |
|----------|-------------|
| `set_encoding` | 出力エンコーディングを強制 (デフォルト: UTF-8) |
| `set_canonical` | `1` で明示的タグ付きの正規化 YAML を出力 |
| `set_indent` | インデント幅 (2〜9、デフォルト 2) |
| `set_width` | 推奨行幅 (デフォルト 80、`-1` で無制限) |
| `set_unicode` | `1` で非 ASCII 文字をエスケープせずに出力 |
| `set_break` | 改行スタイル |

#### `emitter_emit`

イベントを出力する。イベントは消費され、再利用できない。

```
emitter_emit :: proc(emitter: ^emitter_t, event: ^event_t) -> c.int
```

**戻り値:** 成功時 `1`、エラー時 `0`。

#### `emitter_flush`

蓄積された出力をフラッシュする。

```
emitter_flush :: proc(emitter: ^emitter_t) -> c.int
```

### イベント初期化関数

`event_t` を準備して `emitter_emit` に渡す。すべて成功時 `1`、エラー時 `0` を返す。

```
stream_start_event_initialize   :: proc(event: ^event_t, encoding: encoding_t) -> c.int
stream_end_event_initialize     :: proc(event: ^event_t) -> c.int

document_start_event_initialize :: proc(
    event: ^event_t,
    version_directive: ^version_directive_t,  // nil でデフォルト
    tag_directives_start: [^]tag_directive_t, // nil でデフォルト
    tag_directives_end: [^]tag_directive_t,   // nil でデフォルト
    implicit: c.int,                          // 1 で --- を省略
) -> c.int
document_end_event_initialize   :: proc(event: ^event_t, implicit: c.int) -> c.int
                                         // implicit: 1 で ... を省略

alias_event_initialize          :: proc(event: ^event_t, anchor: [^]char_t) -> c.int

scalar_event_initialize :: proc(
    event: ^event_t,
    anchor: [^]char_t,       // nil でアンカーなし
    tag: [^]char_t,          // nil で自動タグ
    value: [^]char_t,        // スカラー値
    length: c.int,           // 値のバイト長
    plain_implicit: c.int,   // 1 でプレーンスタイルを許可
    quoted_implicit: c.int,  // 1 でクォートスタイルを許可
    style: scalar_style_t,   // スカラースタイル
) -> c.int

sequence_start_event_initialize :: proc(
    event: ^event_t,
    anchor: [^]char_t,       // nil でアンカーなし
    tag: [^]char_t,          // nil で自動タグ
    implicit: c.int,         // 1 でタグを省略
    style: sequence_style_t, // シーケンススタイル
) -> c.int
sequence_end_event_initialize   :: proc(event: ^event_t) -> c.int

mapping_start_event_initialize  :: proc(
    event: ^event_t,
    anchor: [^]char_t,       // nil でアンカーなし
    tag: [^]char_t,          // nil で自動タグ
    implicit: c.int,         // 1 でタグを省略
    style: mapping_style_t,  // マッピングスタイル
) -> c.int
mapping_end_event_initialize    :: proc(event: ^event_t) -> c.int
```

### イベント発行の順序

エミッタに渡すイベントは以下の順序に従う必要がある:

```
STREAM-START
  DOCUMENT-START
    (ノード: SCALAR | SEQUENCE-START ... SEQUENCE-END | MAPPING-START ... MAPPING-END)
  DOCUMENT-END
  ... (複数ドキュメント可)
STREAM-END
```

### サンプル: 文字列バッファへの YAML 出力

**コード:**

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

BUFFER_SIZE :: 16 * 1024

main :: proc() {
    buf: [BUFFER_SIZE]c.uchar
    written: c.size_t

    emitter: yaml.emitter_t
    assert(yaml.emitter_initialize(&emitter) != 0)
    defer yaml.emitter_delete(&emitter)

    yaml.emitter_set_output_string(&emitter, raw_data(buf[:]), BUFFER_SIZE, &written)
    yaml.emitter_set_unicode(&emitter, 1)

    event: yaml.event_t

    emit_scalar :: proc(e: ^yaml.emitter_t, ev: ^yaml.event_t, val: string) {
        yaml.scalar_event_initialize(
            ev, nil, nil, raw_data(val), c.int(len(val)), 1, 1, .ANY_SCALAR_STYLE,
        )
        yaml.emitter_emit(e, ev)
    }

    // ストリーム開始
    yaml.stream_start_event_initialize(&event, .UTF8_ENCODING)
    yaml.emitter_emit(&emitter, &event)

    // ドキュメント開始
    yaml.document_start_event_initialize(&event, nil, nil, nil, 0)
    yaml.emitter_emit(&emitter, &event)

    // ルートマッピング
    yaml.mapping_start_event_initialize(&event, nil, nil, 1, .BLOCK_MAPPING_STYLE)
    yaml.emitter_emit(&emitter, &event)

    emit_scalar(&emitter, &event, "name")
    emit_scalar(&emitter, &event, "odin-libyaml")

    emit_scalar(&emitter, &event, "version")
    emit_scalar(&emitter, &event, "0.1.0")

    // ネストされたシーケンス
    emit_scalar(&emitter, &event, "authors")
    yaml.sequence_start_event_initialize(&event, nil, nil, 1, .BLOCK_SEQUENCE_STYLE)
    yaml.emitter_emit(&emitter, &event)
    emit_scalar(&emitter, &event, "Alice")
    emit_scalar(&emitter, &event, "Bob")
    yaml.sequence_end_event_initialize(&event)
    yaml.emitter_emit(&emitter, &event)

    // マッピング終了
    yaml.mapping_end_event_initialize(&event)
    yaml.emitter_emit(&emitter, &event)

    // ドキュメント終了
    yaml.document_end_event_initialize(&event, 0)
    yaml.emitter_emit(&emitter, &event)

    // ストリーム終了
    yaml.stream_end_event_initialize(&event)
    yaml.emitter_emit(&emitter, &event)

    fmt.print(string(buf[:written]))
}
```

**出力:**

```yaml
---
name: odin-libyaml
version: 0.1.0
authors:
- Alice
- Bob
...
```

---

## ダンパ (ドキュメントベース出力)

ダンパ API はメモリ上にドキュメントツリーを構築し、一括でシリアライズする。ドキュメント全体を出力前に構築できる場合は、イベントベースのエミッタより簡潔に書ける。

### ドキュメント構築関数

#### `document_initialize`

空のドキュメントを作成する。

```
document_initialize :: proc(
    document: ^document_t,
    version_directive: ^version_directive_t,      // nil でデフォルト
    tag_directives_start: [^]tag_directive_t,      // nil でデフォルト
    tag_directives_end: [^]tag_directive_t,        // nil でデフォルト
    start_implicit: c.int,  // 1 で --- を省略
    end_implicit: c.int,    // 1 で ... を省略
) -> c.int
```

**戻り値:** 成功時 `1`。

#### `document_add_scalar`

スカラーノードをドキュメントに追加する。

```
document_add_scalar :: proc(
    document: ^document_t,
    tag: [^]char_t,         // nil でデフォルト (tag:yaml.org,2002:str)
    value: [^]char_t,       // スカラー値
    length: c.int,          // 値のバイト長
    style: scalar_style_t,  // スカラースタイル
) -> c.int
```

**戻り値:** 1始まりのノードインデックス。エラー時は `0`。

#### `document_add_sequence`

空のシーケンスノードを追加する。

```
document_add_sequence :: proc(
    document: ^document_t,
    tag: [^]char_t,            // nil でデフォルト (tag:yaml.org,2002:seq)
    style: sequence_style_t,   // シーケンススタイル
) -> c.int
```

**戻り値:** 1始まりのノードインデックス。エラー時は `0`。

#### `document_add_mapping`

空のマッピングノードを追加する。

```
document_add_mapping :: proc(
    document: ^document_t,
    tag: [^]char_t,           // nil でデフォルト (tag:yaml.org,2002:map)
    style: mapping_style_t,   // マッピングスタイル
) -> c.int
```

**戻り値:** 1始まりのノードインデックス。エラー時は `0`。

#### `document_append_sequence_item`

シーケンスノードに要素を追加する。

```
document_append_sequence_item :: proc(
    document: ^document_t,
    sequence: c.int,       // シーケンスのノードインデックス
    item: c.int,           // 追加する要素のノードインデックス
) -> c.int
```

**戻り値:** 成功時 `1`。

#### `document_append_mapping_pair`

マッピングノードにキー/値ペアを追加する。

```
document_append_mapping_pair :: proc(
    document: ^document_t,
    mapping: c.int,        // マッピングのノードインデックス
    key: c.int,            // キーのノードインデックス
    value: c.int,          // 値のノードインデックス
) -> c.int
```

**戻り値:** 成功時 `1`。

### ダンパ関数

#### `emitter_open`

エミッタストリームを開く (STREAM-START を出力)。`emitter_dump` の前に呼ぶ必要がある。

```
emitter_open :: proc(emitter: ^emitter_t) -> c.int
```

#### `emitter_dump`

ドキュメントをエミッタの出力先にシリアライズする。**ドキュメントは消費される** — 内部で `document_delete` が呼ばれる。

```
emitter_dump :: proc(emitter: ^emitter_t, document: ^document_t) -> c.int
```

#### `emitter_close`

エミッタストリームを閉じる (STREAM-END を出力)。

```
emitter_close :: proc(emitter: ^emitter_t) -> c.int
```

### サンプル: ドキュメントを構築してダンプする

**コード:**

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

BUFFER_SIZE :: 16 * 1024

main :: proc() {
    buf: [BUFFER_SIZE]c.uchar
    written: c.size_t

    emitter: yaml.emitter_t
    assert(yaml.emitter_initialize(&emitter) != 0)
    defer yaml.emitter_delete(&emitter)

    yaml.emitter_set_output_string(&emitter, raw_data(buf[:]), BUFFER_SIZE, &written)
    yaml.emitter_open(&emitter)

    document: yaml.document_t
    yaml.document_initialize(&document, nil, nil, nil, 0, 0)

    // ヘルパー: スカラーノードを追加
    add_scalar :: proc(doc: ^yaml.document_t, val: string) -> c.int {
        return yaml.document_add_scalar(
            doc, nil, raw_data(val), c.int(len(val)), .ANY_SCALAR_STYLE,
        )
    }

    // ツリーを構築: { app: myservice, ports: [8080, 8443] }
    root := yaml.document_add_mapping(&document, nil, .BLOCK_MAPPING_STYLE)

    k1 := add_scalar(&document, "app")
    v1 := add_scalar(&document, "myservice")
    yaml.document_append_mapping_pair(&document, root, k1, v1)

    k2 := add_scalar(&document, "ports")
    seq := yaml.document_add_sequence(&document, nil, .FLOW_SEQUENCE_STYLE)
    yaml.document_append_sequence_item(&document, seq, add_scalar(&document, "8080"))
    yaml.document_append_sequence_item(&document, seq, add_scalar(&document, "8443"))
    yaml.document_append_mapping_pair(&document, root, k2, seq)

    // ダンプ (ドキュメントはここで消費される)
    yaml.emitter_dump(&emitter, &document)
    yaml.emitter_close(&emitter)

    fmt.print(string(buf[:written]))
}
```

**出力:**

```yaml
---
app: myservice
ports: [8080, 8443]
...
```

---

## エラー処理

失敗しうる libyaml 関数はすべて `c.int` を返す: 成功時 `1`、失敗時 `0`。

失敗時、パーサまたはエミッタの構造体にエラーの詳細が格納される:

**パーサのエラー確認:**

```odin
parser: yaml.parser_t
// ... 呼び出し失敗後:
if parser.error != .NO_ERROR {
    fmt.eprintfln("エラー種別: %v", parser.error)
    fmt.eprintfln("問題:       %s", parser.problem)
    fmt.eprintfln("位置:       %d行目 %d列目",
        parser.problem_mark.line + 1,
        parser.problem_mark.column + 1,
    )
}
```

**エミッタのエラー確認:**

```odin
emitter: yaml.emitter_t
// ... 呼び出し失敗後:
if emitter.error != .NO_ERROR {
    fmt.eprintfln("エラー種別: %v", emitter.error)
    fmt.eprintfln("問題:       %s", emitter.problem)
}
```

### エラー種別一覧

| 値 | 意味 |
|-------|---------|
| `NO_ERROR` | エラーなし |
| `MEMORY_ERROR` | メモリ確保に失敗 |
| `READER_ERROR` | 入力の読み取りエラーまたは不正なエンコーディング |
| `SCANNER_ERROR` | 入力に不正なトークンが含まれている |
| `PARSER_ERROR` | 不正な YAML 構造 |
| `COMPOSER_ERROR` | 不正なドキュメント構造 (例: 未定義のエイリアス) |
| `WRITER_ERROR` | 出力の書き込みエラー |
| `EMITTER_ERROR` | エミッタへの不正なイベント列 |

### サンプル: パースエラーの処理

**入力:**

```yaml
items:
	- bad indent
```

(タブ文字がインデントに使用されている — YAML では不正)

**コード:**

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := "items:\n\t- bad indent\n"

    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    event: yaml.event_t
    for {
        if yaml.parser_parse(&parser, &event) == 0 {
            fmt.eprintfln("パースエラー %d行目 %d列目: %s",
                parser.problem_mark.line + 1,
                parser.problem_mark.column + 1,
                parser.problem,
            )
            return
        }
        done := event.type == .STREAM_END_EVENT
        yaml.event_delete(&event)
        if done do break
    }
}
```

**出力:**

```
パースエラー 2行目 0列目: found character that cannot start any token
```

---

## タグ定数

以下の YAML タグ定数が利用可能:

| 定数 | 値 |
|------|-----|
| `YAML_NULL_TAG` | `"tag:yaml.org,2002:null"` |
| `YAML_BOOL_TAG` | `"tag:yaml.org,2002:bool"` |
| `YAML_STR_TAG` | `"tag:yaml.org,2002:str"` |
| `YAML_INT_TAG` | `"tag:yaml.org,2002:int"` |
| `YAML_FLOAT_TAG` | `"tag:yaml.org,2002:float"` |
| `YAML_TIMESTAMP_TAG` | `"tag:yaml.org,2002:timestamp"` |
| `YAML_SEQ_TAG` | `"tag:yaml.org,2002:seq"` |
| `YAML_MAP_TAG` | `"tag:yaml.org,2002:map"` |

デフォルトタグ:

| 定数 | 値 |
|------|-----|
| `YAML_DEFAULT_SCALAR_TAG` | `YAML_STR_TAG` |
| `YAML_DEFAULT_SEQUENCE_TAG` | `YAML_SEQ_TAG` |
| `YAML_DEFAULT_MAPPING_TAG` | `YAML_MAP_TAG` |

---

## その他

### `set_max_nest_level`

パーサの最大ネスト深度を設定する。デフォルトは 0 (無制限)。

```
set_max_nest_level :: proc(max: c.int)
```

### よく使うパターン

**`[^]char_t` を Odin の `string` に変換:**

```odin
// 長さが既知の場合 (例: scalar.length):
value := string(node.data.scalar.value[:node.data.scalar.length])
```

**Odin の `string` を libyaml に渡す:**

```odin
// パーサへの入力設定
yaml.parser_set_input_string(&parser, raw_data(input), len(input))

// スカラーイベントの初期化
yaml.scalar_event_initialize(
    &event, nil, nil,
    raw_data(value), c.int(len(value)),
    1, 1, .ANY_SCALAR_STYLE,
)
```

**シーケンスの要素を走査:**

```odin
items := node.data.sequence.items
count := (uintptr(items.end) - uintptr(items.start)) / size_of(yaml.node_item_t)
for i in 0 ..< count {
    child := yaml.document_get_node(&document, items.start[i])
    // child を使って処理
}
```

**マッピングのペアを走査:**

```odin
pairs := node.data.mapping.pairs
count := (uintptr(pairs.end) - uintptr(pairs.start)) / size_of(yaml.node_pair_t)
for i in 0 ..< count {
    pair := pairs.start[i]
    key := yaml.document_get_node(&document, pair.key)
    val := yaml.document_get_node(&document, pair.value)
    // key, val を使って処理
}
```

---

## 高レベル Unmarshal API

`unmarshal` 系の関数は、リフレクションを使用して YAML データを直接 Odin の構造体にデコードする。YAML データを利用する最も簡単な方法。

### `unmarshal`

YAML バイト列を型付きポインタにデコードする。

```
unmarshal :: proc(data: []byte, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error
```

### `unmarshal_string`

YAML 文字列を型付きポインタにデコードする。

```
unmarshal_string :: proc(data: string, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error
```

### `unmarshal_any`

`any` を受け取る低レベル版。値はポインタでなければならない。

```
unmarshal_any :: proc(data: []byte, v: any, allocator := context.allocator) -> Unmarshal_Error
```

### サポートされる型

| Odin 型 | YAML ノード型 | 備考 |
|---------|-------------|------|
| `string`, `cstring` | スカラー | アロケータ経由でクローンされる |
| `bool`, `b8`..`b64` | スカラー | `true/false/yes/no/on/off` (大文字小文字バリエーション) |
| `int`, `i8`..`i128`, `u8`..`u128` | スカラー | 10進数、`0x` 16進数、`0o` 8進数、`0b` 2進数 |
| `f16`..`f64` | スカラー | `.inf`, `-.inf`, `.nan` にも対応 |
| `enum` | スカラー | 名前マッチ (完全一致 → 大文字小文字無視)、または整数値 |
| `struct` | マッピング | `yaml` 構造体タグまたはフィールド名で照合 |
| `struct` | シーケンス | 位置ベースマッピング: 要素が宣言順にフィールドを埋める |
| `[]T` (スライス) | シーケンス | アロケータ経由で確保 |
| `[dynamic]T` | シーケンス | アロケータ経由で確保 |
| `[N]T` (固定長配列) | シーケンス | 最大 N 要素まで |
| `map[string]T` | マッピング | キーと値が再帰的にデコードされる |
| `^T` (ポインタ) | 任意 | 確保して再帰; `null` → `nil` |
| `Maybe(T)` | 任意 | 非 null 値でバリアントが設定される |
| 複数バリアント `union` | 任意 | 各バリアントを順に試行 |

### 構造体タグ

`yaml` 構造体タグでフィールド名のマッピングを制御できる:

```odin
Config :: struct {
    api_key:     string `yaml:"api-key"`,     // YAML キー "api-key" にマッピング
    internal_id: string `yaml:"-"`,           // unmarshal 時に無視
    name:        string,                       // YAML キー "name" にマッピング
}
```

### エラー型

```
Unmarshal_Error :: union {
    Unmarshal_Data_Error,       // .Invalid_Data, .Invalid_Parameter, .Non_Pointer_Parameter
    Unsupported_Type_Error,     // struct { id: typeid }
    Yaml_Parse_Error,           // struct { problem: string, line: int, column: int }
    Scalar_Conversion_Error,    // struct { value: string, target_type: typeid }
    runtime.Allocator_Error,
}
```

### サンプル: 基本的な unmarshal

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    Server :: struct {
        host: string,
        port: int,
    }
    Config :: struct {
        name:   string,
        debug:  bool,
        server: Server,
        tags:   []string,
    }

    input := `
name: my-app
debug: true
server:
  host: localhost
  port: 8080
tags:
  - web
  - api
`
    cfg: Config
    err := yaml.unmarshal_string(input, &cfg)
    if err != nil {
        fmt.eprintfln("エラー: %v", err)
        return
    }

    fmt.printfln("名前:     %s", cfg.name)
    fmt.printfln("デバッグ: %v", cfg.debug)
    fmt.printfln("サーバ:   %s:%d", cfg.server.host, cfg.server.port)
    fmt.printfln("タグ:     %v", cfg.tags)
}
```

**出力:**

```
名前:     my-app
デバッグ: true
サーバ:   localhost:8080
タグ:     [web, api]
```

---

## カスタムデコーダ

デフォルトのリフレクションベースデコードでは不十分な場合 — 例えば、YAML スカラーを複雑な構造体にパースする必要がある場合や、ある型が複数の YAML 表現を受け付ける場合 — カスタムデコーダ (Unmarshaler) を登録できる。

`core:encoding/json` パッケージと同じ **`map[typeid]proc` グローバルレジストリパターン** を採用している。

### 型定義

#### `Unmarshal_Context`

カスタムデコーダプロシージャに渡されるコンテキスト。現在の YAML ノードとヘルパー関数へのアクセスを提供する。

```
Unmarshal_Context :: struct {
    doc:       ^document_t,    // YAML ドキュメント
    node:      ^node_t,        // 現在のノード
    allocator: mem.Allocator,  // メモリアロケータ
}
```

#### `User_Unmarshaler`

カスタムデコーダのプロシージャ型。`v` はデコード先のデータを直接指す `any` (ポインタへのポインタではない)。

```
User_Unmarshaler :: #type proc(ctx: Unmarshal_Context, v: any) -> Unmarshal_Error
```

#### `Register_User_Unmarshaler_Error`

```
Register_User_Unmarshaler_Error :: enum {
    None,                         // 成功
    No_User_Unmarshaler,          // レジストリ未初期化 (set_user_unmarshalers 未呼び出し)
    Unmarshaler_Previously_Found, // 型が既に登録済み
}
```

### レジストリ関数

#### `set_user_unmarshalers`

カスタムデコーダレジストリを初期化する。`nil` を渡すとカスタムデコードを無効にする。

```
set_user_unmarshalers :: proc(m: ^map[typeid]User_Unmarshaler)
```

#### `register_user_unmarshaler`

特定の型にカスタムデコーダを登録する。

```
register_user_unmarshaler :: proc(id: typeid, unmarshaler: User_Unmarshaler) -> Register_User_Unmarshaler_Error
```

### コンテキストヘルパー関数

カスタムデコーダ内でノードの検査やデコードの委譲に使用する。

#### `unmarshal_ctx_decode`

現在のノードを標準のリフレクションベースデコードに委譲する。無限再帰を避けるため、現在の型のカスタムデコーダはスキップされる。

```
unmarshal_ctx_decode :: proc(ctx: Unmarshal_Context, target: any) -> Unmarshal_Error
```

#### `unmarshal_ctx_decode_node`

指定したノードを対象の値にデコードする。対象の型にカスタムデコーダが登録されている場合は**呼び出される**。

```
unmarshal_ctx_decode_node :: proc(ctx: Unmarshal_Context, node: ^node_t, target: any) -> Unmarshal_Error
```

#### `unmarshal_ctx_node_type`

現在のノードの型を返す。

```
unmarshal_ctx_node_type :: proc(ctx: Unmarshal_Context) -> node_type_t
```

戻り値: `.NO_NODE`, `.SCALAR_NODE`, `.SEQUENCE_NODE`, `.MAPPING_NODE`

#### `unmarshal_ctx_node_value`

現在のノードのスカラー値を文字列として返す。スカラーでない場合は `""` を返す。

```
unmarshal_ctx_node_value :: proc(ctx: Unmarshal_Context) -> string
```

#### `unmarshal_ctx_mapping_pairs`

マッピングノードのキー/値ペアをスライスとして返す。

```
unmarshal_ctx_mapping_pairs :: proc(ctx: Unmarshal_Context) -> []node_pair_t
```

#### `unmarshal_ctx_sequence_items`

シーケンスノードの要素をスライスとして返す。

```
unmarshal_ctx_sequence_items :: proc(ctx: Unmarshal_Context) -> []node_item_t
```

#### `unmarshal_ctx_get_node`

ID (1始まりインデックス) でドキュメントからノードを取得する。

```
unmarshal_ctx_get_node :: proc(ctx: Unmarshal_Context, id: node_item_t) -> ^node_t
```

### 実行順序

`unmarshal_node` が値を処理する際の順序:

1. **カスタムデコーダチェック** — その型に `User_Unmarshaler` が登録されていれば即座に呼び出す
2. **ポインタ処理** — メモリを確保し、参照先の型で再帰
3. **Union 処理** — 各バリアントを順に試行 (`Maybe(T)` を含む)
4. **ノード型ディスパッチ** — リフレクションによるスカラー / マッピング / シーケンス処理

### サンプル: 16進文字列とマッピングの両方に対応する Color 型

```odin
import "core:fmt"
import "core:strconv"
import yaml "../.."

Color :: struct {
    r: u8,
    g: u8,
    b: u8,
}

color_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
    switch yaml.unmarshal_ctx_node_type(ctx) {
    case .SCALAR_NODE:
        // "#RRGGBB" 形式をパース
        s := yaml.unmarshal_ctx_node_value(ctx)
        c := (^Color)(v.data)
        if len(s) == 7 && s[0] == '#' {
            r, r_ok := strconv.parse_int(s[1:3], 16)
            g, g_ok := strconv.parse_int(s[3:5], 16)
            b, b_ok := strconv.parse_int(s[5:7], 16)
            if r_ok && g_ok && b_ok {
                c.r = u8(r)
                c.g = u8(g)
                c.b = u8(b)
                return nil
            }
        }
        return yaml.Scalar_Conversion_Error{value = s, target_type = v.id}

    case .MAPPING_NODE:
        // {r, g, b} マッピングは標準デコードに委譲
        return yaml.unmarshal_ctx_decode(ctx, v)

    case .SEQUENCE_NODE, .NO_NODE:
        return nil
    }
    return nil
}

main :: proc() {
    // レジストリを初期化
    unmarshalers: map[typeid]yaml.User_Unmarshaler
    defer delete(unmarshalers)
    yaml.set_user_unmarshalers(&unmarshalers)
    defer yaml.set_user_unmarshalers(nil)

    yaml.register_user_unmarshaler(Color, color_unmarshaler)

    Theme :: struct {
        bg: Color,
        fg: Color,
    }

    input := `
bg: "#1a2b3c"
fg:
  r: 255
  g: 255
  b: 255
`
    theme: Theme
    err := yaml.unmarshal_string(input, &theme)
    if err != nil {
        fmt.eprintfln("エラー: %v", err)
        return
    }

    fmt.printfln("bg: #%2x%2x%2x", theme.bg.r, theme.bg.g, theme.bg.b)
    fmt.printfln("fg: rgb(%d, %d, %d)", theme.fg.r, theme.fg.g, theme.fg.b)
}
```

**出力:**

```
bg: #1a2b3c
fg: rgb(255, 255, 255)
```

### サンプル: 人間が読みやすい文字列をパースする Duration 型

```odin
import "core:fmt"
import "core:strconv"
import yaml "../.."

Duration :: struct {
    seconds: int,
}

duration_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
    if yaml.unmarshal_ctx_node_type(ctx) != .SCALAR_NODE {
        return yaml.unmarshal_ctx_decode(ctx, v)
    }

    s := yaml.unmarshal_ctx_node_value(ctx)
    d := (^Duration)(v.data)
    total := 0
    num_start := 0

    for i := 0; i < len(s); i += 1 {
        switch s[i] {
        case 'h':
            if n, ok := strconv.parse_int(s[num_start:i]); ok { total += n * 3600 }
            num_start = i + 1
        case 'm':
            if n, ok := strconv.parse_int(s[num_start:i]); ok { total += n * 60 }
            num_start = i + 1
        case 's':
            if n, ok := strconv.parse_int(s[num_start:i]); ok { total += n }
            num_start = i + 1
        }
    }

    // サフィックスなしの整数 → 秒として扱う
    if num_start == 0 {
        if n, ok := strconv.parse_int(s); ok {
            total = n
        } else {
            return yaml.Scalar_Conversion_Error{value = s, target_type = v.id}
        }
    }

    d.seconds = total
    return nil
}

main :: proc() {
    unmarshalers: map[typeid]yaml.User_Unmarshaler
    defer delete(unmarshalers)
    yaml.set_user_unmarshalers(&unmarshalers)
    defer yaml.set_user_unmarshalers(nil)

    yaml.register_user_unmarshaler(Duration, duration_unmarshaler)

    Config :: struct {
        timeout:     Duration,
        retry_delay: Duration,
    }

    input := `
timeout: 1h30m
retry_delay: 30s
`
    cfg: Config
    yaml.unmarshal_string(input, &cfg)
    fmt.printfln("timeout:     %d 秒", cfg.timeout.seconds)
    fmt.printfln("retry_delay: %d 秒", cfg.retry_delay.seconds)
}
```

**出力:**

```
timeout:     5400 秒
retry_delay: 30 秒
```

### サンプル: スカラー・マッピング・シーケンスのすべてを受け付ける柔軟な型

```odin
import "core:fmt"
import "core:strconv"
import yaml "../.."

Point :: struct {
    x: int,
    y: int,
}

point_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
    switch yaml.unmarshal_ctx_node_type(ctx) {
    case .SCALAR_NODE:
        // "x,y" 形式をパース
        s := yaml.unmarshal_ctx_node_value(ctx)
        p := (^Point)(v.data)
        for i := 0; i < len(s); i += 1 {
            if s[i] == ',' {
                if xv, ok := strconv.parse_int(s[:i]); ok { p.x = xv }
                if yv, ok := strconv.parse_int(s[i+1:]); ok { p.y = yv }
                return nil
            }
        }
        return nil

    case .MAPPING_NODE:
        // 標準の構造体デコードに委譲: {x: 10, y: 20}
        return yaml.unmarshal_ctx_decode(ctx, v)

    case .SEQUENCE_NODE:
        // 位置ベース: [10, 20]
        items := yaml.unmarshal_ctx_sequence_items(ctx)
        p := (^Point)(v.data)
        if len(items) >= 2 {
            x_node := yaml.unmarshal_ctx_get_node(ctx, items[0])
            y_node := yaml.unmarshal_ctx_get_node(ctx, items[1])
            if x_node != nil {
                yaml.unmarshal_ctx_decode_node(ctx, x_node, any{&p.x, typeid_of(int)})
            }
            if y_node != nil {
                yaml.unmarshal_ctx_decode_node(ctx, y_node, any{&p.y, typeid_of(int)})
            }
        }
        return nil

    case .NO_NODE:
        return nil
    }
    return nil
}
```

このデコーダにより、同じ `Point` 型に対して3つの YAML 表現が使用可能になる:

```yaml
# スカラー形式
origin: "10,20"

# マッピング形式
origin:
  x: 10
  y: 20

# シーケンス形式
origin: [10, 20]
```
