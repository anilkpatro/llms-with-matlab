% This script demonstrates how to use the MatlabAgent class with LM Studio
% to create a ReAct agent that can perform a web search.

% Define the LM Studio endpoint
lmStudioEndpoint = "http://localhost:1234/v1/chat/completions";

% Create a tool for web search
searchTool = openAIFunction("websearch", "Searches the web for the given query.");
searchTool = addParameter(searchTool, "query", "string", "The search query.");

% Create the agent
agent = MatlabAgent([searchTool], EndPoint=lmStudioEndpoint);

% Run the agent
response = agent.run("What is the weather in Boston?");
disp(response)

function results = websearch(query)
    % In a real application, you would use a web search API here.
    % For this example, we'll just return a dummy result.
    results = "The weather in " + query + " is sunny.";
end
