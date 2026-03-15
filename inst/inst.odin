package main

import "core:mem"

// YAML 楽器定義ファイルから読み込んだ情報を格納するランタイム構造体。
// YAML_FORMAT.md の全パターンを網羅する。
// unmarshal 一発マッピング対応の正規化形式。
//
// メモリ管理: すべてのアロケーションを Dynamic_Arena で一括管理する。
// inst_destroy() で arena ごと一発解放。個別の delete は不要。

// --- トップレベル ---

Inst :: struct {
	_arena:          mem.Dynamic_Arena     `yaml:"-"`,  // 全アロケーションを一括管理
	name:            string,              // 楽器名 (必須)
	vendor:          string,              // メーカー名 (必須)
	manufacturer_id: [dynamic]u8,         // SysEx Manufacturer ID (1 or 3 bytes)
	model_id:        [dynamic]u8,         // SysEx Model ID (可変長)
	channel:         Maybe(int),          // デフォルト MIDI チャンネル (1-16)

	note:            Maybe(Inst_Note),
	bend:            Maybe(Inst_Bend),
	aftertouch:      Maybe(Aftertouch_Type),
	program:         Maybe(Inst_Range),   // プログラムチェンジ [min, max]
	bank:            Maybe(Inst_Bank),
	drum:            [dynamic]Inst_Drum_Entry,

	cc:              [dynamic]Inst_CC,
	cc14:            [dynamic]Inst_CC14,
	nrpn:            [dynamic]Inst_NRPN,
	rpn:             [dynamic]Inst_RPN,
	sysex:           [dynamic]Inst_Sysex,

	layers:          [dynamic]Inst_Layer,  // NRPN レイヤーオフセット
	parts:           [dynamic]Inst_Layer,  // NRPN パートオフセット (layers と同構造)
}

// --- note ---

Inst_Note :: struct {
	velocity: bool,                       // ベロシティ対応 (default: true)
	range:    Inst_Range,                 // ノート番号範囲 [min, max] (default: [0, 127])
}

// --- bend ---
// flat struct で全パターンを表現。
// up/down が非ゼロ → 非対称レンジ
// range が非ゼロ → 対称レンジ
// min/max/offset が非ゼロ → signed 生値

Inst_Bend :: struct {
	up:     int,                          // ベンドアップ半音数
	down:   int,                          // ベンドダウン半音数
	range_: int   `yaml:"range"`,        // ±半音 (対称)
	min:    int,
	max:    int,
	offset: int,
}

// --- aftertouch ---

Aftertouch_Type :: enum {
	Channel,
	Poly,
	Both,
}

// --- program / bank ---
// sequence [min, max] → positional mapping で自動変換

Inst_Range :: struct {
	min: int,
	max: int,
}

Inst_Bank :: struct {
	msb:     Maybe(Inst_Range),           // CC#0 MSB 範囲 (省略 = MSB 不使用)
	lsb:     Maybe(Inst_Range),           // CC#32 LSB 範囲 (省略 = LSB 不使用)
	program: Inst_Range,                  // バンク内プログラム範囲
}

// --- drum ---

Inst_Drum_Entry :: struct {
	name:        string,                  // 音色名 (例: "kick", "bd")
	note_number: int,                     // MIDI ノート番号
}

// --- 共通修飾型 ---

Inst_Signed :: struct {
	min:    int,
	max:    int,
	offset: int,
}

Inst_Array :: struct {
	from: int,                            // インデックス開始値
	to:   int,                            // インデックス終了値 (inclusive)
	step: int,                            // CC/LSB 番号の増分
}

Inst_Enum_Entry :: struct {
	label:     string,
	min_value: int,                       // 単一値の場合 min == max
	max_value: int,
}

// --- CC (7-bit) ---

Inst_CC :: struct {
	name:          string,                // パラメータ名 ("cutoff", "bd.tune" 等)
	cc:            int,                   // CC 番号 (0-127)
	default_value: Maybe(int)            `yaml:"default"`,
	enum_entries:  [dynamic]Inst_Enum_Entry `yaml:"enum"`,
	signed_range:  Maybe(Inst_Signed)    `yaml:"signed"`,
	array_range:   Maybe(Inst_Array)     `yaml:"array"`,
}

// --- CC14 (14-bit) ---

Inst_CC14 :: struct {
	name:         string,
	msb:          int,                    // MSB CC 番号 (0-31)
	lsb:          int,                    // LSB CC 番号 (32-63)
	enum_entries: [dynamic]Inst_Enum_Entry `yaml:"enum"`,
	signed_range: Maybe(Inst_Signed)     `yaml:"signed"`,
}

// --- NRPN ---

Inst_NRPN :: struct {
	name:         string,
	msb:          int,                    // NRPN アドレス MSB (CC#99 値)
	lsb:          int                    `yaml:"-"`,  // カスタムデコーダで処理
	lsb_is_note:  bool                   `yaml:"-"`,  // カスタムデコーダで処理
	value_range:  Maybe(Inst_Range)      `yaml:"range"`,
	enum_entries: [dynamic]Inst_Enum_Entry `yaml:"enum"`,
	signed_range: Maybe(Inst_Signed)     `yaml:"signed"`,
	array_range:  Maybe(Inst_Array)      `yaml:"array"`,
}

// --- RPN ---

Inst_RPN :: struct {
	name:         string,
	msb:          int,                    // RPN アドレス MSB (CC#101 値)
	lsb:          int,                    // RPN アドレス LSB (CC#100 値)
	value_range:  Maybe(Inst_Range)      `yaml:"range"`,
	signed_range: Maybe(Inst_Signed)     `yaml:"signed"`,
}

// --- layers / parts ---

Inst_Layer :: struct {
	name:        string,                  // レイヤー/パート識別名 ("layer_a", "voice_1" 等)
	nrpn_offset: int,                     // NRPN アドレスに加算するオフセット
}

// --- SysEx ---

Inst_Sysex :: struct {
	name:   string,                       // テンプレート識別名
	params: [dynamic]string,              // パラメータ名リスト (省略時は空)
	body:   [dynamic]Inst_Sysex_Element,  // メッセージ本体
}

Inst_Sysex_Element_Kind :: enum {
	Literal,                              // 固定バイト値
	Param_Ref,                            // params で宣言したパラメータ参照
	Channel,                              // MIDI チャンネル埋め込み
	Device_Id,                            // デバイス ID 埋め込み
	Checksum,                             // チェックサム計算・挿入
	Vararg,                               // 可変長データ展開
}

Inst_Sysex_Element :: struct {
	kind:  Inst_Sysex_Element_Kind,
	value: u8,                            // Literal の場合のバイト値
	name:  string,                        // Param_Ref / Vararg の場合のパラメータ名
	base:  Maybe(int),                    // Channel の場合の base 値 (省略時 = 0)
}

// --- 初期化・解放 ---

// arena allocator を返す。unmarshal にこれを渡すことで全アロケーションが arena に集約される。
inst_init :: proc(inst: ^Inst) -> mem.Allocator {
	mem.dynamic_arena_init(&inst._arena)
	return mem.dynamic_arena_allocator(&inst._arena)
}

// arena ごと一括解放。個別の delete は不要。
inst_destroy :: proc(inst: ^Inst) {
	mem.dynamic_arena_destroy(&inst._arena)
}
