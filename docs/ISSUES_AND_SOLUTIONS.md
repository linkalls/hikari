## 概要

このドキュメントは、`hikari` プロジェクト開発中に出会った主なつまずき（コンパイルエラー、ランタイムの不整合、性能上の検討点）と、それに対して実施した解決策や今後の改善案をまとめたものです。

目的:

- 問題の原因を記録して再発を防ぐ
- どのファイルをどう修正したかを追跡する
- 今後の改善（未解決事項）を明確にする

## 重要な変更点（ざっくり）

- Trie ルート/ルーティング（`hikari/app.v`）の書き換え：unsafe を使わずにパラメータ子ノードを `children[':']` のような特別キーで扱う設計に変更。
- バッファプール（`hikari/pool.v`）の導入：レスポンスボディの []u8 を再利用して割当を減らす。
- レスポンス型を `[]u8` ボディ + `body_str` キャッシュにして、veb への変換とバッファ還元を分離。
- フレームワーク側でワーカー数自動検出（`detect_workers()`）と、マスター/ワーカープロセスの起動ロジックを `hikari/app.v` に組み込んだ。
- ワーカーの stdout/stderr を `logs/worker_<port>.log` にリダイレクトして端末出力を抑制するようにした（マスターはフォアグラウンドで `server_port` を担当）。

## 発生した主な問題と対処

1. V コンパイラのエラー／警告（map に対するポインタ参照や null 許容）

原因:

- V の map に格納されたポインタ値の取り扱いは制約があり、直接 null を代入/参照するとコンパイルエラーや未定義挙動になる。

対処:

- unsafe を使わない方針に合わせ、Trie の設計を変更して `children map[string]&TrieNode` のうち、パラメータ子ノードはキー `":"`（コロン）で保存し、`param_name` をそのノードに保持するようにした。これにより null ポインタ操作を回避できた。
- map から値を取る際は `or {}` を使う等 V のセーフティ規則に従った。

該当ファイル: `hikari/app.v`

2. String API の違い（`trim_prefix` 等が使えない）

原因:

- 使っていた API が環境/バージョンで利用できなかったか、期待していたメソッドが存在しないケース。

対処:

- スライス操作や `starts_with` を用いて明示的に先頭の `'/'` を削る実装に変更。

該当箇所: ルート挿入・マッチ処理中の path 正規化（`hikari/app.v`）。

3. バッファプールでの暗黙クローン警告（`implicit clone`）

原因:

- V の所有権ルール上、slice を 0 長にして返すときに暗黙クローンが発生する場合があり、コンパイラが注意を促す。

対処:

- 現状は明示的な `.clone()` を使って警告を回避した（実装トレードオフ）。
- 将来的には unsafe を使わずにメモリを再利用する別アプローチ（固定長バッファ管理や独自ポインタプール）を検討する必要がある。

該当ファイル: `hikari/pool.v`

4. ワーカープロセスの起動と端末の扱い（親プロセスがすぐ終了してしまう／端末が返ってしまう）

症状:

- 以前はマスターがワーカーを spawn して親が即座に exit したため、ユーザの端末がプロンプトに戻り、サーバがバックグラウンドで動くように見えた（望ましくない）。また spawn ごとに多数行ログが端末に出て煩雑だった。

対処:

- 挙動を変更: マスターはバックグラウンドワーカー（`server_port+1 ..`）を `nohup <exe> --port <port> --hikari-child > logs/worker_<port>.log 2>&1 &` で起動してデタッチさせ、親プロセスはフォアグラウンドとして `server_port` のワーカーを担当するようにした。
- また、子ごとの起動ログは suppress し、要約メッセージのみ出すようにした。

該当ファイル: `hikari/app.v`（master/child spawn ロジック）

5. ワーカーの標準出力が端末に重複表示される／全て port 3000 と表示されるログ不整合

原因:

- 生成したワーカーがそれぞれ同じログ出力を行っていた箇所（起動メッセージが定数や環境変数の解釈ミスで同じ port を出力していた）。

対処:

- 子プロセスを nohup で起動し、各ワーカーの stdout/stderr を `logs/worker_<port>.log` に切り替えたため、端末側に重複出力は出なくなった。
- 子の起動メッセージは最小限に抑え、各子は自プロセス起動時に自身の `--port` 引数を読み取ってログを生成するようにしている（port 表示の不一致が残る場合は、該当ログ出力箇所を `server_port` の直読みするよう修正する）。

6. ゼロコピー経路（veb へ直接 []u8 を渡す）

現状:

- 現在は `Response.body` を文字列化して `veb_ctx.text(...)` に渡す実装で、ボディを []u8 のまま直接 write するゼロコピー経路は検討中（実装保留）。

懸念と対処案:

- veb の API がバイト列直接書き込みをサポートするなら、そちらを使って `body` を直接書き込み、変換コストを削減するのが理想。サポートがない場合はバイト → 文字列変換を最適化しつつプールを有効活用する。

## ベンチマークと再現コマンド

プロダクションビルド:

```bash
v -prod -o bin/hikari_server example/main.v
./bin/hikari_server
```

ベンチマークコマンド例:

```bash
bombardier --fasthttp -d 10s -c 100 http://localhost:3000/hello
```

実行例の結果（セッション抜粋）:

- Run A: Reqs/sec Avg 74,626.05, Latency Avg 1.34ms
- Run B: Reqs/sec Avg 106,168.62, Latency Avg 0.94ms

## 変更した主なファイル一覧（目的を一行で）

- `hikari/app.v` — ルーティング、master/worker spawn、サーバ起動ロジック
- `hikari/pool.v` — BufferPool 実装（rent/give）
- `hikari/static_responses.v` — テスト用の高速レスポンス生成
- `example/main.v` — フレームワークを使うサンプルアプリ（`app.fire()` 呼び出し）
- `scripts/run_workers.sh`, `scripts/bench_and_profile.sh` — ベンチ＆起動用の補助スクリプト
- `nginx/hikari_upstream.conf` — nginx upstream の例

## 未解決・改善候補（優先度付き）

1. pool.give の clone を避ける（中〜高）

   - 現状は `.clone()` によるコピーで警告を回避しているが、理想はメモリ再利用でコピーを避けること。
   - 代替案: 固定長バッファ・リングバッファを実装する、または v の所有権ルールに沿った形で slice の長さを安全にリセットする実装を検討。

2. ゼロコピー経路の実装（高）

   - veb の API を詳しく確認し、もし `write_bytes` 相当があれば `Response.body` を直接書く。これで文字列変換コストをほぼゼロにできる。

3. ワーカーのプロセス管理（中）

   - 現状は `nohup` 起動で簡易デタッチしているが、PID 管理や graceful shutdown を実装するなら supervisor 的な仕組み（systemd ユニットや parent が子を保持する設計）を検討する。

4. プロファイリング（中）
   - `perf record` → `perf script` → FlameGraph 等でホットスポットを可視化する。`scripts/bench_and_profile.sh` はその入り口を用意している。

## 参考: よく使う復旧コマンド

プロセス一覧（hikari_server）:

```bash
ps aux | grep hikari_server
```

ログ確認:

```bash
tail -f logs/worker_3001.log
tail -f logs/benchmark_3000.log
```

強制終了（注意して使う）:

```bash
pkill -f bin/hikari_server
```

## 最後に

このドキュメントは随時更新してください。追記／修正があれば内容を教えてください。

## 追加: パラメータルートで 404 が出る時のデバッグ手順（例: `/aa/:name/aa/:q` が `/aa/aa/aa/11` にマッチしない）

症状:

- 指定したパラメータ付きルートが期待どおりマッチせず 404 が返る。

よくある原因:

- HTTP メソッドの大文字／小文字差（`GET` と `get`）で登録された map キーが異なる。
- ルートの定義とリクエストパスのセグメント数/順序が一致していない（`/:id` は単一セグメントのみを表す）。
- ルート登録時に正しい method キーで trie に挿入されていない（実装ミスやバグ）。

診断手順:

1. リクエスト時のメソッドが大文字化されているか確認

   - `create_hikari_context` で `method` を `.to_upper()` にしているか確認。されていなければ `GET` が `get` として扱われ、map 参照に失敗する可能性がある。

2. 実際に登録されたルートを確認する（デバッグ用追加）
   - 一時的に `hikari/app.v` にルート一覧を出力するヘルパを追加して起動すると確認しやすい。
   - 例（本番に入れる前のデバッグ用）:

```v
// debug: dump registered routes
fn (app &Hikari) dump_routes() {
   println('=== exact_routes ===')
   for method, m in app.exact_routes {
      for p, _ in m {
         println('$method $p')
      }
   }
   println('=== tries ===')
   for method, _ in app.tries {
      println('trie for method: $method')
   }
}

// 起動時に呼ぶ
// app.dump_routes()
```

3. curl でパスを叩く際の例:

```bash
curl -i http://localhost:3000/aa/aa/aa/11
```

4. 子ワーカーを使っている場合、処理ログは `logs/worker_<port>.log` に出るため、そのファイルを確認する:

```bash
tail -n 200 logs/worker_3000.log
```

原因別の修正方法:

- メソッドの大小問題: `add_route` で `method.to_upper()` を使ってキーを正規化し、リクエスト側でも `create_hikari_context` で大文字化する（既に実装済み）。
- セグメント不一致: ルート文字列を確認し、期待するセグメント数と順序が合っているか検証する。例えば `/aa/:name/aa/:q` はちょうど 4 セグメント（先頭に `/` を含めると）を期待する。`/aa/aa/aa/11` はマッチするはずだが、余分なスラッシュや URL エンコーディングがないかチェックする。
- ルート競合: より具体的な静的ルートが `exact_routes` に登録されていないか、または別のパラメータ化ルートが先に優先される設計になっていないかを確認する（実装による）。

補足:

- 現状のルーターは `:` で表す単一セグメントのパラメータをサポートします。複数セグメントをキャプチャするワイルドカード（例: `:path...`）は現行実装では部分的にサポートしていないため、そのような要件がある場合は設計の拡張が必要です。

---

（注）あなたが示した `example/main.v` のハンドラ実装は正しく、`/aa/:name/aa/:q` と `/aa/aa/aa/11` は理論上マッチするはずです。もしまだ 404 が続くなら、上の診断手順を試してログや `dump_routes()` の出力を共有してください。私がさらに原因を突き止めてパッチを当てます。
