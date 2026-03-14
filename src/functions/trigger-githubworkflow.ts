const { DefaultAzureCredential } = require("@azure/identity");

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER;
const GITHUB_REPO = process.env.GITHUB_REPO;
const WORKFLOW_FILE = "agent-pr.yml";

async function triggerWorkflow(agentDefinition, deploymentName) {
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches`;

  await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      ref: "main",
      inputs: {
        deployment_name: deploymentName,
        agent_definition: JSON.stringify(agentDefinition),
      },
    }),
  });
}

module.exports = async function (context, req) {
  const {
    data: { alertContext },
  } = JSON.parse(req.rawBody);

  const {
    operationName,
    properties: { entity, message },
  } = alertContext;

  if (
    operationName ===
    "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write"
  ) {
    if (
      message ===
      "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write"
    ) {
      context.log("DEPLOY");

      try {
        const parts = entity.split("/");

        const subscriptionId = parts[2];
        const resourceGroup = parts[4];
        const accountName = parts[8];
        const projectName = parts[10];
        const appName = parts[12];
        const deploymentName = parts[14];

        const credential = new DefaultAzureCredential();

        const token = await credential.getToken(
          "https://management.azure.com/.default",
        );

        const url =
          `https://management.azure.com/subscriptions/${subscriptionId}` +
          `/resourceGroups/${resourceGroup}` +
          `/providers/Microsoft.CognitiveServices/accounts/${accountName}` +
          `/projects/${projectName}/applications/${appName}` +
          `/agentDeployments/${deploymentName}` +
          `?api-version=2025-10-01-preview`;

        const deploymentRes = await fetch(url, {
          headers: {
            Authorization: `Bearer ${token.token}`,
          },
        });

        const deployment = await deploymentRes.json();
        const agent = deployment.properties.agents[0];
        const { agentName } = agent;

        context.log("Agent:", agentName);

        const endpoint = `https://${accountName}.services.ai.azure.com/api/projects/${projectName}`;
        const agentUrl = `${endpoint}/agents/${agentName}?api-version=v1`;

        const aiFoundryToken = await credential.getToken(
          "https://ai.azure.com/.default",
        );

        const agentRes = await fetch(agentUrl, {
          headers: {
            Authorization: `Bearer ${aiFoundryToken.token}`,
          },
        });

        const agentObj = await agentRes.json();
        const agentVersions = agentObj.versions;
        const agentLatestVersion = agentVersions.latest;

        const agentDefinition = agentLatestVersion.definition;

        context.log("Agent definition fetched");

        // GitHub Actions workflow起動
        await triggerWorkflow(agentDefinition, deploymentName);

        context.log("GitHub workflow dispatched");
      } catch (err) {
        context.log("Agent fetch error", err);
      }
    }

    if (
      message ===
      "Microsoft.CognitiveServices/accounts/projects/applications/write"
    ) {
      context.log("SAVE");
    }
  }

  context.res = {
    status: 200,
    body: "OK",
  };
};
