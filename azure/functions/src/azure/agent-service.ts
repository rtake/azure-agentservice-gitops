import { DefaultAzureCredential } from "@azure/identity";

const SCOPE = "https://ai.azure.com/.default";

export const fetchAgentDefinition = async ({
  credential,
  accountName,
  projectName,
  agentName,
}: {
  credential: DefaultAzureCredential;
  accountName: string;
  projectName: string;
  agentName: string;
}): Promise<object> => {
  const token = await credential.getToken(SCOPE);

  const domain = `${accountName}.services.ai.azure.com`;
  const projectEndpoint = `https://${domain}/api/projects/${projectName}`;
  const agentEndpoint = `${projectEndpoint}/agents/${agentName}?api-version=v1`;

  const agentRes = await fetch(agentEndpoint, {
    headers: {
      Authorization: `Bearer ${token.token}`,
    },
  });

  const {
    versions: {
      latest: { definition: agentDefinition },
    },
  } = await agentRes.json();

  return agentDefinition;
};
