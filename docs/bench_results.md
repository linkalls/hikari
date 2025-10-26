# ベンチ結果と変更履歴

この文書はローカル環境での簡易的なパフォーマンス改善作業の記録です。

実行環境（このセッション）

- OS: Linux
- CPU: nproc = 10
- ベンチツール: bombardier (fasthttp)
- ベンチ負荷: duration=10s, concurrency=100 (デフォルトスクリプト)

目的

- `scripts/bench_and_profile.sh` と `scripts/bench_compare.sh` の不具合を修正
- ベンチ実行時に親プロセスしか起動していなかった問題を修正
- パフォーマンスをできるだけ改善（目標: 2x 向上を目指す）

やったこと（要約）

- `scripts/bench_and_profile.sh` を修正

  - サーバ起動時に常に `HIKARI_WORKERS=1` を上書きしていた問題を修正
  - デフォルトでパフォーマンス向けの環境変数をセットする `PERF_MODE` を追加（デフォルト ON）
    - `HIKARI_WORKERS` を CPU コア数に設定（未指定時）、`HIKARI_CHILD_STDIO=devnull`、`HIKARI_POOL_BUF=2048`、`HIKARI_POOL_COUNT=4096`
  - サーバが起動するまで待ち、終了時に確実に停止する `trap cleanup` を追加

- `scripts/bench_compare.sh` を修正

  - bombardier の出力パースで壊れていた awk 部分を修正
  - 実行後に `docs/bench_results.md` に集計行を追記するように改善

- `hikari/context.v` を修正
  - `text/json/html` のヘルパで不要な byte 配列割当を避けるように変更（body は空配列、body_str を使う）
  - これによりリクエストごとの割当を削減

計測結果（同一マシン、bombardier -d 10s -c 100）

- 変更前（単一ワーカーを明示した実行）

  - Reqs/sec ≈ 18,127 req/s

- 変更後（PERF_MODE によるチューニング + 子 stdio を devnull、プール増量）

  - Reqs/sec ≈ 111,348 req/s

- 追加最適化（レスポンスヘルパで byte 割当を削減）後
  - Reqs/sec ≈ 113,750 req/s

結果のまとめ

- 単一ワーカー実行から比べると ~6x の改善を確認しました。
- 直近の施策（PERF_MODE + バッファ割当最小化）で、自動検出／複数ワーカー環境下のスループットが大幅に向上しました（例: ~18k → ~113k req/s）。

次の改善案（2x を達成するための候補）

1. プロファイル取得
   - `perf record` / `perf report` または `pprof` でホットスポットを特定。現状の改善は主に並列化と I/O 回避だが、CPU ホットスポット（JSON エンコードやルーティング）を見つけられれば更に改善可能。
2. ルーティング最適化
   - Parameterized route のトライ探索は速いが、さらに高速化する余地がある（最小化された文字列処理や少ないメモリアクセス）。
3. JSON エンコード回避
   - ベンチ対象が固定レスポンスであれば、事前にエンコードした文字列を返す、あるいはカスタムの軽量エンコーダを使う。
4. ネットワークレイヤ／うまく設定された fasthttp/keepalive
   - サーバ側の TCP チューニング（listen backlog、socket options）、およびクライアント側の接続数調整。
5. バッファプールのさらなるチューニング
   - 現在は BUF=2048, COUNT=4096 を試した。さらに最適なサイズはワークロードに依存するため、`bench_compare.sh` で網羅的に調査をおすすめします。

再現手順（最短）

1. 依存: `bombardier` をインストール
2. ルートで実行（デフォルトで PERF_MODE=1）:

```bash
bash scripts/bench_and_profile.sh
```

パフォーマンス比較: 単一ワーカー vs PERF_MODE

```bash
# 単一ワーカー（比較用）
HIKARI_WORKERS=1 bash scripts/bench_and_profile.sh

# PERF チューニング
bash scripts/bench_and_profile.sh
```

補足

- `PERF_MODE` を切りたければ `PERF_MODE=0 bash scripts/bench_and_profile.sh` で元の挙動（env を上書きしない）に戻せます。
- 本リポジトリの `example/main.v` はシンプルなレスポンスを返すように設計されています。実アプリケーションではミドルウェアや JSON シリアライズが大きな影響を与えるため、アプリ側の最適化も重要です。

必要なら、このドキュメントにベンチ出力（生データ）や `perf` の取り方、さらに深いコードレベルの最適化パッチを追加で当てます。どれを優先しましょうか？

# Benchmark results

| Config | HIKARI_WORKERS | HIKARI_CHILD_STDIO | Req/s (avg) | Latency (avg) |
| ------ | -------------: | -----------------: | ----------: | ------------: |
