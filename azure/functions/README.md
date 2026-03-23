#　概要

GitHub Actionsのワークフローを実行するAzure Functions

## detect-agent-publish

## upload-agent-from-queue

# 設定

## ビルド・デプロイ

```
cd azure/functions
npm i
npm run build # ビルド
func azure functionapp publish <FunctionAppName> # デプロイ
```

### ロール割り当て

`upload-agent-from-queue` ではAI Foundryにアクセするためのロールが必要です。
デプロイした Azure FunctionsにCognitive Serviceユーザーロールを割り当ててください。
