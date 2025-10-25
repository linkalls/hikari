## Hikari パフォーマンス調査チェックリスト

目的: まず怪しそうな箇所を洗い出し、ベンチ/プロファイルで再現 → 修正 → 再ベンチという反復を回しやすくすること。

優先順位順のチェック項目（仮）：

1. リクエスト経路のマッチング

   - `exact_routes` は O(1) だが、parameterized routes は trie をたどる実装になっている。
   - 確認: 静的ルートが多い場合、trie を通るフォールバックが走っていないか。hot path の条件分岐やコピーが無いか。
   - 測定: 静的ルートのみでベンチして差分を確認する。

2. 標準出力 / println のコスト

   - `println`/`eprintln` は同期的 I/O を伴い高負荷下で大きく足を引っ張る。
   - 対策: 開発用の `println` は無効化、logger を非同期/ファイルへ切り替え、もしくは高負荷時にはミドルウェアでログを外せるようにする。

3. Logger ミドルウェア

   - デフォルトでコンソール出力すると顕著に性能が落ちる。
   - 測定: `app.use(hikari.logger())` を外したベースラインと比較。`logger({'file': true})` でファイル書き込み時の挙動も比較。

4. 子プロセスの stdio ハンドリング

   - 現在は親プロセスが子の stdio をパイプで受けてバックグラウンドでドレインしている。これ自体は軽いが、不要なら子を直接 `/dev/null` へ向けるオプションの方が低オーバーヘッド。
   - 測定: 親がドレインする実装と子で `/dev/null` に再定向する実装を比較。

5. BufferPool と bytes->string

   - `Response.body` の bytes->string 変換はコストがかかるため、`body_str` キャッシュや zero-copy を検討。
   - 測定: 小さなレスポンス（"Hello, World" 等）で bytes→string の挙動を確認し、不要なコピーが無いかをチェック。

6. プロセス数とワーカー数の最適化

   - `detect_workers()` の挙動を理解し、CPU コア数・I/O 負荷に応じて最適なワーカー数を手動で試す。
   - 測定: `HIKARI_WORKERS` を明示して 1, cpu, cpu\*2 などでベンチ。

7. GC / アロケーション
   - 毎リクエスト allocate/deallocate が多いと GC がボトルネックになる可能性あり。map や一時配列の生成を最小化する。

手順（すぐに試せる簡単な流れ）:

1. ベースライン取得（現在やったのと同じ）

   ```bash
   bombardier --fasthttp -d 10s -c 100 http://localhost:3000/
   ```

2. logger を切る（`example/main.v` の `app.use(hikari.logger())` をコメントアウト）して再ベンチ。

3. `println` を全て削除またはコメントアウトして再ベンチ。

4. 親のドレインをやめ、子の stdio を `/dev/null` にリダイレクトする変更を試して再ベンチ。

5. `HIKARI_WORKERS` を明示してワーカー数を変更し、最適値を探索。

計測自動化スクリプト: `../scripts/run_benchmark.sh` を併用してください（次のファイルを参照）。

次のタスク候補（優先度高）:

- `example/main.v` から開発用 println を削除または `#if debug` で囲む
- logger を非同期化または負荷時にスキップ可能にする
- 子 stdio をファイル/`/dev/null` に直接リダイレクトするオプションを追加
- 詳細プロファイルのセットアップ（`perf` / `pprof` 相当）

追記: `HIKARI_CHILD_STDIO` オプション

- 概要: 親プロセスが子プロセスの stdout/stderr をパイプで受け取る実装は高負荷下でオーバーヘッドになるため、子を直接 `/dev/null` にリダイレクトするオプションを追加しました。環境変数 `HIKARI_CHILD_STDIO=devnull` を親に設定すると、子プロセスの stdio を `/dev/null` に向けて起動します（spawn 時のみ小さなシェルを使うため起動コストはわずかに増えますが、リクエストホットパスのオーバーヘッドは減ります）。

- 使い方:

  ```bash
  # マスターから子を spawn する場合に有効化
  export HIKARI_CHILD_STDIO=devnull
  ./bin/hikari_server --port 3000
  ```

- 備考: 開発中は標準出力ログが欲しいことが多いので `HIKARI_CHILD_STDIO` は負荷試験や CI ベンチのときのみ有効化するのが簡単で安全です。

Fiber 比較と性能向上の試行案

- 背景: 参考ベンチマークとして “Fiber - 13,509,592 responses per second with an average latency of 0.9 ms” という数値が提示されています（環境依存のため単純比較は難しいですが、目標値の一つとして使えます）。

- 目的: 上記のスコアを越える、あるいは同等以上の RPS/低レイテンシを安定して出すための試行案を列挙します。

実験リスト（優先度順）:

1. ログ無効化 + println 削除

   - `example/main.v` の `println` を完全に削除、`app.use(hikari.logger())` を外してベースラインを取得。
   - 測定: `./scripts/run_benchmark.sh http://localhost:3000/ 10s 100`

2. `HIKARI_CHILD_STDIO=devnull` を有効化してワーカー起動

   - 親が子の stdio を受け取らないようにして、パイプオーバーヘッドを排除。
   - 測定: ワーカー数を変えつつ比較（例: 1, cpu, cpu\*2）。

3. BufferPool の活用と body_str キャッシュ

   - 小さなレスポンスで bytes->string のコピーを避けられるよう `Response.body_str` を活用するコードパスを確認/最適化。

4. 子プロセス数チューニング

   - `HIKARI_WORKERS` を明示して 1, cpu, cpu\*2 を比較。プロセス間でのスケジューリングを考慮して最適値を探る。

5. ミドルウェア最小化

   - 不要なミドルウェアを外してルーティング／ハンドラのホットパスを短くする。

6. Zero-copy/メモリ割当削減

   - 一時配列や map の生成を減らす。`BufferPool` の容量を調整してアロケーション頻度を下げる。

7. ネイティブツールで詳細プロファイル
   - `perf`、`eBPF`（bcc/tracee）、あるいは pprof 相当でホットループ、syscall、コンテキストスイッチを確認。

測定の自動化（例）:

- 1 ワーカー、ログあり/なし、devnull on/off を自動で比較する簡易シェルの骨子:

  ```bash
  # 例: ベンチ比較の流れ
  # 1) ビルド
  v -prod -o bin/hikari_server example/main.v

  # 2) 1ワーカーで起動（ログあり）
  ./bin/hikari_server --port 3000 > logs/worker_3000.log 2>&1 & pid=$!
  ./scripts/run_benchmark.sh http://localhost:3000/ 10s 100
  kill $pid

  # 3) 1ワーカーで起動（HIKARI_CHILD_STDIO=devnull）
  export HIKARI_CHILD_STDIO=devnull
  ./bin/hikari_server --port 3000 > logs/worker_3000.log 2>&1 & pid=$!
  ./scripts/run_benchmark.sh http://localhost:3000/ 10s 100
  kill $pid
  ```

成功基準（暫定）:

- 目的のスループット（例: 1M RPS 以上、または Fiber の提示値に近づくこと）を得ること。まずは安定して 100k+ RPS を出せる状態を第一目標にし、そこから段階的に最適化を進める。

注: ハードウェアやカーネル設定（TCP backlog, somaxconn, network stack offloads）でも大きく差が出ます。比較時はできるだけ同一環境で計測してください。

---

初版: 2025-10-25
