# Prism ネイティブ API への RubyParser 書き直し

## 目的

parser gem / ast gem への依存を外し、Prism のノードクラスを直接扱う実装に置き換える。
既存の `SolidScore::Parser::RubyParser` の出力（ClassInfo / MethodInfo）は原則そのまま維持する。

## 進め方

1. 旧 RubyParser と並行して `PrismParser` を新規実装する
2. 既存の ruby_parser_spec を shared examples 化し、両パーサーで走らせる
3. 全 fixture について新旧の出力を比較する parity spec を置く
4. parity が取れたら RubyParser を新実装に差し替え、旧実装・parser・ast を削除する

## テスト（Red → Green の順に消していく）

- [x] simple_class からクラス名・superclass・メソッド数を取り出せる
- [x] private 以降のメソッド可視性を検出できる
- [x] インスタンス変数を検出できる
- [x] 継承を検出できる
- [x] 1 ファイル複数クラス
- [x] include を検出できる
- [x] メソッド内の呼び出しを検出できる
- [x] memoized factory (`@x ||= Foo.new`) を検出できる
- [x] 以降、既存 ruby_parser_spec の残り example
- [x] 全 fixture で新旧の出力が一致する（parity spec）
- [x] 構文エラーで `SolidScore::Parser::SyntaxError` を投げる
- [x] runner / rubocop helpers が新しい例外を rescue する
- [x] 旧実装・parity spec・parser/ast 依存の削除

## 旧実装との意図的な差分

- `::Foo` のような cbase 付き定数名: 旧実装は `"(cbase)::Foo"` を返していた。新実装は `"::Foo"` を返す
- const 以外の superclass（`Struct.new(...)` 等）: 旧実装は AST の dump 文字列を返していた。新実装はソース文字列を返す

## 移行後の課題（別 PR）

- `private def foo` 形式が可視性を巻き込んでメソッドを取り落とす
- `class << self` 内のメソッドが無視される
- `ocp_analyzer` の `type == :block` は parser の `:blockarg` と一致しない（常に false）
- `dip_analyzer` の keyword 判定に `:key/:keyreq` が混在している
- `&.` による safe navigation 呼び出し: 旧実装は呼び出しとして記録していなかった。新実装は通常の呼び出しと同様に記録する
- `->` ラムダ: 旧実装は `lambda` メソッド呼び出し + ブロックの 2 文として数えていた。新実装は 1 文として数え、呼び出しには含めない
- 番号付きパラメータ (`_1`) や `it` を使うブロック: 旧実装は数えていなかった。新実装は通常のブロックと同様に 1 文として数える
- パターンマッチの変数束縛 (`in [x, y]`): 新実装は代入として 1 文ずつ数える
- `def foo(...)` の引数転送: 旧実装は parameters に含めていなかった。新実装は `[:forward_arg, nil]` を返す
- 分割代入パラメータ `def foo((a, b))`: 旧実装は AST ノードオブジェクトをそのまま名前として返していた。新実装は `[:mlhs, nil]` を返す
- `/re/ =~ str` のような正規表現リテラルとのマッチ: 旧実装は呼び出しとして記録していなかった。新実装は `=~` の呼び出しとして記録する
- `begin ... end while cond`: 旧実装は循環的複雑度に加算していなかった。新実装は通常の `while` と同様に 1 加算する
- `@x ||= Foo.new do ... end` のようにブロック付きのファクトリ呼び出し: 旧実装はメモ化ファクトリとして検出していなかった。新実装は検出する
- `extend self`: 旧実装は `"(self)"` と報告していた。新実装は `"self"` と報告する
- 文字列リテラルに UTF-8 と互換性のないエスケープを含むファイル（activesupport の `digest/uuid.rb` 等）: 旧実装は構文エラーとして読み飛ばしていた。新実装は解析する
