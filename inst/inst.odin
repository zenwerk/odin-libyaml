package main

// YAML 楽器定義ファイルから読み込んだ情報を格納するランタイム構造体。
// YAML_FORMAT.md の全パターンを網羅する。

// --- トップレベル ---

Inst :: struct {
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
	drums:           [dynamic]Inst_Drum_Entry,

	ccs:             [dynamic]Inst_CC,
	cc14s:           [dynamic]Inst_CC14,
	nrpns:           [dynamic]Inst_NRPN,
	rpns:            [dynamic]Inst_RPN,
	sysexes:         [dynamic]Inst_Sysex,

	layers:          [dynamic]Inst_Layer,  // NRPN レイヤーオフセット
	parts:           [dynamic]Inst_Layer,  // NRPN パートオフセット (layers と同構造)
}

// --- note ---

Inst_Note :: struct {
	velocity: bool,                       // ベロシティ対応 (default: true)
	range:    Inst_Range,                 // ノート番号範囲 [min, max] (default: [0, 127])
}

// --- bend ---
// 3 形式を union で表現:
//   Bend_Symmetric  — range: 12
//   Bend_Asymmetric — up: 12, down: 2
//   Bend_Signed     — min/max/offset (14-bit 生値)
//   nil             — bend: true (レンジ未指定)

Inst_Bend :: struct {
	detail: Bend_Detail,
}

Bend_Detail :: union {
	Bend_Symmetric,
	Bend_Asymmetric,
	Bend_Signed,
}

Bend_Symmetric :: struct {
	range: int,                           // ±半音 (対称)
}

Bend_Asymmetric :: struct {
	up:   int,                            // ベンドアップ半音数
	down: int,                            // ベンドダウン半音数
}

Bend_Signed :: struct {
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
	default_value: Maybe(int),            // 初期値
	enum_entries:  [dynamic]Inst_Enum_Entry,
	signed_range:  Maybe(Inst_Signed),
	array_range:   Maybe(Inst_Array),
}

// --- CC14 (14-bit) ---

Inst_CC14 :: struct {
	name:         string,
	msb:          int,                    // MSB CC 番号 (0-31)
	lsb:          int,                    // LSB CC 番号 (32-63)
	enum_entries: [dynamic]Inst_Enum_Entry,
	signed_range: Maybe(Inst_Signed),
}

// --- NRPN ---
// lsb が `note` (per-note ドラムパラメータ) の場合、lsb_is_note = true, lsb = 0

Inst_NRPN :: struct {
	name:         string,
	msb:          int,                    // NRPN アドレス MSB (CC#99 値)
	lsb:          int,                    // NRPN アドレス LSB (CC#98 値)。lsb_is_note=true の場合は無視
	lsb_is_note:  bool,                  // true: LSB はランタイムでノート番号が入る
	value_range:  Maybe(Inst_Range),      // 値の [min, max]
	enum_entries: [dynamic]Inst_Enum_Entry,
	signed_range: Maybe(Inst_Signed),
	array_range:  Maybe(Inst_Array),      // LSB 連番展開
}

// --- RPN ---

Inst_RPN :: struct {
	name:         string,
	msb:          int,                    // RPN アドレス MSB (CC#101 値)
	lsb:          int,                    // RPN アドレス LSB (CC#100 値)
	value_range:  Maybe(Inst_Range),
	signed_range: Maybe(Inst_Signed),
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

// --- 解放 ---

inst_free :: proc(inst: ^Inst) {
	delete(inst.manufacturer_id)
	delete(inst.model_id)
	delete(inst.drums)

	for &cc in inst.ccs {
		delete(cc.enum_entries)
	}
	delete(inst.ccs)

	for &cc14 in inst.cc14s {
		delete(cc14.enum_entries)
	}
	delete(inst.cc14s)

	for &nrpn in inst.nrpns {
		delete(nrpn.enum_entries)
	}
	delete(inst.nrpns)

	delete(inst.rpns)

	for &sx in inst.sysexes {
		delete(sx.params)
		delete(sx.body)
	}
	delete(inst.sysexes)

	delete(inst.layers)
	delete(inst.parts)
}
