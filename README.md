# azurefunctions-githubworkflow

## 概要

本リポジトリは、Azure AI Foundry Agent Serviceにおけるエージェント発行をトリガーに、エージェント定義を GitHub に自動エクスポートし、Pull Requestを作成するイベント駆動パイプラインの実装例を提供します。

本番環境の安定稼働を目的としてAI Foundryを開発環境と本番環境で分離して運用する場合、開発したエージェントを本番環境へ反映するプロセスが必要になります。しかし、手作業によるエクスポートと反映では、変更履歴の追跡やレビュー・承認プロセスの担保が難しいという課題があります。

本パイプラインでは、開発環境でのエージェント発行を Activity Logから検知し、エージェント定義の取得・GitHub へのコミット・Pull Request の作成までを自動化します。さらに、Pull Request のマージをトリガーとして本番環境へエージェントを発行するワークフローを組み込むことで、変更のレビューを挟んだ GitOps ベースの運用フローを実現します。

## プロジェクト構成

### upload-agent-to-github

GitHubにエージェント定義をアップロードするAzure Functions
HTTPリクエストからエージェントの情報を取得し, GitHub Acrionsのワークフローを起動する

#### 引数

- `agentDefinition`: object
- `deploymentName`: string

### agent-pr.yml

エージェント情報を受け取り, 作成したブランチ上でエージェント定義をコミット/Push/PR作成まで実行する

## テスト

.envにURLとキーを記載し, シェルスクリプトを実行

```
cd test-scripts/upload-agent-to-github
bash trigger.sh
```
