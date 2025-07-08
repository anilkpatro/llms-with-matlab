classdef tlmstudioFunction < matlab.unittest.TestCase
% Tests for openAIFunction with LM Studio server

%   Copyright 2023-2025 The MathWorks, Inc.

    properties(TestParameter)
        ValidProperties = iGetValidProperties();
    end

    properties
        lmstudioEndpoint = "http://localhost:1134/v1/chat/completions";
        lmstudioAPIKey = "lm-studio";
        lmstudioModel = "local-model";
    end

    methods(Test)

        function testCreateFunctionWithDescription(testCase)
            name = "functionName";
            description = "description here";
            funObj = openAIFunction(name, description);
            testCase.verifyEqual(funObj.FunctionName, name);
            testCase.verifyEqual(funObj.Description, description);
        end

        function testCreateFunctionWithoutDescription(testCase)
            name = "functionName";
            funObj = openAIFunction(name);
            testCase.verifyEqual(funObj.FunctionName, name);
            testCase.verifyEmpty(funObj.Description);
        end

        function testParametersAreAdded(testCase)
            funObj = openAIFunction("getCurrentWeather");

            funObj = addParameter(funObj, "location", type="string", description="City and state.");
            funObj = addParameter(funObj, "format", type="string", enum=["celsius", "fahrenheit"]);

            parameters = struct("location", struct("type", "string", "description", "City and state.", "required", true), ...
                "format", struct("type", "string", "enum", ["celsius", "fahrenheit"], "required", true));

            testCase.verifyEqual(funObj.Parameters, parameters);
        end

        function testValidProperties(testCase, ValidProperties)
            funObj = openAIFunction("functionName");
            testCase.verifyWarningFree(@()addParameter(funObj, "parameterName", ValidProperties{:}));
        end

        function testValidOutputStructWithParameters(testCase)
            % Format expected from LM Studio (should be same as OpenAI)
            expectedStruct = struct("name", "getCurrentWeather", ...
                "parameters", struct("type", "object", ...
                    "properties", struct( ...
                        "location", struct("type", "string", "description", "City and state."), ...
                        "format", struct("type", "string", "enum", {["celsius", "fahrenheit"]})), ...
                    "required", {["location", "format"]}));

            funObj = openAIFunction("getCurrentWeather");
            funObj = addParameter(funObj, "location", type="string", description="City and state.");
            funObj = addParameter(funObj, "format", type="string", enum=["celsius", "fahrenheit"]);

            testCase.verifyEqual(encodeStruct(funObj), expectedStruct);
        end

        function testValidOutputStructWithoutParameters(testCase)
            % Format expected from LM Studio (should be same as OpenAI)
            expectedStruct = struct("name", "getCurrentWeather", ...
                "parameters", struct("type", "object", ...
                    "properties", struct()));

            funObj = openAIFunction("getCurrentWeather");

            testCase.verifyEqual(encodeStruct(funObj), expectedStruct);
        end

        function testFunctionCallWithLMStudio(testCase)
            % Test actual function calling with LM Studio server
            func = openAIFunction("get_weather", "Get current weather for a location");
            func = addParameter(func, "location", type="string", description="The city and state/country");
            
            chat = openAIChat("You are a helpful assistant that can check weather.", ...
                ModelName=testCase.lmstudioModel, ...
                EndPoint=testCase.lmstudioEndpoint, ...
                APIKey=testCase.lmstudioAPIKey, ...
                Tools=func);
            
            [response, message] = testCase.verifyWarningFree(...
                @()generate(chat, "What's the weather like in Paris?"));
            
            % Verify function was called correctly
            if isfield(message, 'tool_calls') && ~isempty(message.tool_calls)
                testCase.verifyEqual(string(message.tool_calls(1).function.name), "get_weather");
                
                % Parse and verify arguments
                args = jsondecode(message.tool_calls(1).function.arguments);
                testCase.verifyTrue(isfield(args, 'location'));
                testCase.verifyTrue(contains(lower(args.location), 'paris'));
            end
        end

        function testMultipleFunctionsWithLMStudio(testCase)
            % Test multiple functions with LM Studio
            weatherFunc = openAIFunction("get_weather", "Get current weather for a location");
            weatherFunc = addParameter(weatherFunc, "location", type="string", description="The city and state/country");
            
            timeFunc = openAIFunction("get_time", "Get current time for a location");
            timeFunc = addParameter(timeFunc, "location", type="string", description="The city and state/country");
            
            chat = openAIChat("You are a helpful assistant.", ...
                ModelName=testCase.lmstudioModel, ...
                EndPoint=testCase.lmstudioEndpoint, ...
                APIKey=testCase.lmstudioAPIKey, ...
                Tools=[weatherFunc, timeFunc]);
            
            [response, message] = testCase.verifyWarningFree(...
                @()generate(chat, "What time is it in Tokyo?"));
            
            % Verify one of the functions was called
            if isfield(message, 'tool_calls') && ~isempty(message.tool_calls)
                calledFunction = message.tool_calls(1).function.name;
                testCase.verifyTrue(ismember(calledFunction, ["get_weather", "get_time"]));
            end
        end

        function testFunctionWithComplexParameters(testCase)
            % Test function with various parameter types
            func = openAIFunction("complex_function", "A function with complex parameters");
            func = addParameter(func, "text_param", type="string", description="A text parameter");
            func = addParameter(func, "number_param", type="number", description="A number parameter");
            func = addParameter(func, "boolean_param", type="boolean", description="A boolean parameter");
            func = addParameter(func, "enum_param", type="string", enum=["option1", "option2", "option3"], description="An enum parameter");
            func = addParameter(func, "optional_param", type="string", description="An optional parameter", RequiredParameter=false);
            
            chat = openAIChat("You are a helpful assistant.", ...
                ModelName=testCase.lmstudioModel, ...
                EndPoint=testCase.lmstudioEndpoint, ...
                APIKey=testCase.lmstudioAPIKey, ...
                Tools=func);
            
            [response, message] = testCase.verifyWarningFree(...
                @()generate(chat, "Call the complex function with text 'hello', number 42, boolean true, and enum option1"));
            
            % Verify function structure is correct
            expectedStruct = encodeStruct(func);
            testCase.verifyEqual(expectedStruct.name, "complex_function");
            testCase.verifyTrue(isfield(expectedStruct.parameters.properties, 'text_param'));
            testCase.verifyTrue(isfield(expectedStruct.parameters.properties, 'number_param'));
            testCase.verifyTrue(isfield(expectedStruct.parameters.properties, 'boolean_param'));
            testCase.verifyTrue(isfield(expectedStruct.parameters.properties, 'enum_param'));
            testCase.verifyTrue(isfield(expectedStruct.parameters.properties, 'optional_param'));
        end

        function testFunctionNameValidation(testCase)
            % Test that function names are properly validated
            validNames = ["validName", "valid_name", "validName123", "function1"];
            
            for name = validNames
                testCase.verifyWarningFree(@()openAIFunction(name));
            end
        end

        function testLMStudioToolChoiceAuto(testCase)
            % Test tool choice with auto setting
            func = openAIFunction("test_function", "A test function");
            func = addParameter(func, "input", type="string", description="Test input");
            
            chat = openAIChat("You are a helpful assistant.", ...
                ModelName=testCase.lmstudioModel, ...
                EndPoint=testCase.lmstudioEndpoint, ...
                APIKey=testCase.lmstudioAPIKey, ...
                Tools=func);
            
            [response, message] = testCase.verifyWarningFree(...
                @()generate(chat, "Use the test function with input 'hello'", ToolChoice="auto"));
            
            % Should work without errors
            testCase.verifyClass(response, 'string');
        end

        function testLMStudioToolChoiceNone(testCase)
            % Test tool choice with none setting
            func = openAIFunction("test_function", "A test function");
            func = addParameter(func, "input", type="string", description="Test input");
            
            chat = openAIChat("You are a helpful assistant.", ...
                ModelName=testCase.lmstudioModel, ...
                EndPoint=testCase.lmstudioEndpoint, ...
                APIKey=testCase.lmstudioAPIKey, ...
                Tools=func);
            
            [response, message] = testCase.verifyWarningFree(...
                @()generate(chat, "Just say hello, don't use any functions", ToolChoice="none"));
            
            % Should get a regular text response, no function calls
            testCase.verifyClass(response, 'string');
            testCase.verifyGreaterThan(strlength(response), 0);
            
            % Should not have tool_calls in message
            if isfield(message, 'tool_calls')
                testCase.verifyEmpty(message.tool_calls);
            end
        end

        function testInvalidConstructorInputs(testCase)
            % Test invalid constructor inputs
            testCase.verifyError(@()openAIFunction(1, "description"), "MATLAB:validators:mustBeNonzeroLengthText");
            testCase.verifyError(@()openAIFunction("", "description"), "MATLAB:validators:mustBeNonzeroLengthText");
            testCase.verifyError(@()openAIFunction("functionName", 1), "MATLAB:validators:mustBeTextScalar");
        end

        function testInvalidParameterInputs(testCase)
            % Test invalid parameter inputs
            funObj = openAIFunction("functionName");
            testCase.verifyError(@()addParameter(funObj, 1), "MATLAB:validators:mustBeNonzeroLengthText");
            testCase.verifyError(@()addParameter(funObj, ""), "MATLAB:validators:mustBeNonzeroLengthText");
            testCase.verifyError(@()addParameter(funObj, "1param"), "llms:mustBeVarName");
            testCase.verifyError(@()addParameter(funObj, "param", "invalidProperty", "value"), "MATLAB:validators:mustBeMember");
        end
    end
end

function ValidProperties = iGetValidProperties()
    ValidProperties = {};
    ValidProperties{end+1} = {"type", "string"};
    ValidProperties{end+1} = {"type", "number"};
    ValidProperties{end+1} = {"type", "integer"};
    ValidProperties{end+1} = {"type", "object"};
    ValidProperties{end+1} = {"type", "boolean"};
    ValidProperties{end+1} = {"type", "null"};
    ValidProperties{end+1} = {"description", "This is a description"};
    ValidProperties{end+1} = {"enum", ["a", "b", "c"]};
    ValidProperties{end+1} = {"enum", "a"};
    ValidProperties{end+1} = {"type", "string", "description", "This is a description"};
    ValidProperties{end+1} = {"type", "string", "enum", ["a", "b", "c"]};
    ValidProperties{end+1} = {"type", "string", "description", "This is a description", "enum", ["a", "b", "c"]};
end