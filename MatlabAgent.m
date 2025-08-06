classdef MatlabAgent
%MatlabAgent A ReAct agent that uses openAIChat and openAIFunctions.

% Copyright 2024 The MathWorks, Inc.

    properties
        Chat
        MaxTurns = 5;
    end

    methods
        function this = MatlabAgent(tools, nvp)
            arguments
                tools {mustBeA(tools, "openAIFunction")}
                nvp.EndPoint (1,1) string = "https://api.openai.com/v1/chat/completions"
            end

            systemPrompt = "You have access to a set of tools that you can use to answer the user's request. " + ...
                "When you are done, you will respond with the answer. " + ...
                "If you cannot answer the question with the available tools, you will respond with ""I cannot answer this question"".";

            this.Chat = openAIChat(systemPrompt, Tools=tools, EndPoint=nvp.EndPoint);
        end

        function response = run(this, query)
            messages = messageHistory;
            addUserMessage(messages, query);

            for turn = 1:this.MaxTurns
                [text, message] = generate(this.Chat, messages);

                if ~isempty(text)
                    response = text;
                    return
                else
                    tool_calls = message.ToolCalls;
                    addResponseMessage(messages, message);
                    for tool_call = tool_calls
                        func_name = tool_call.function.name;

                        try
                            args = jsondecode(tool_call.function.arguments);
                            args_cell = struct2cell(args);
                            result = feval(func_name, args_cell{:});
                        catch ME
                            result = "Error executing function: " + ME.message;
                        end

                        addToolMessage(messages, tool_call.id, result);
                    end
                end
            end
            response = "Agent could not answer the question within the maximum number of turns.";
        end
    end
end
