# azurefunctions-githubworkflow

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
