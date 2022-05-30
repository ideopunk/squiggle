import * as React from "react";
import _ from "lodash";
import {
  run,
  errorValueToString,
  squiggleExpression,
  bindings,
  environment,
  jsImports,
  defaultImports,
  defaultBindings,
  defaultEnvironment,
  declaration,
} from "@quri/squiggle-lang";
import { NumberShower } from "./NumberShower";
import { DistributionChart } from "./DistributionChart";
import { ErrorBox } from "./ErrorBox";
import { FunctionChart, FunctionChartSettings } from "./FunctionChart";

function getRange<a>(x: declaration<a>) {
  let first = x.args[0];
  switch (first.tag) {
    case "Float": {
      return { floats: { min: first.value.min, max: first.value.max } };
    }
    case "Date": {
      return { time: { min: first.value.min, max: first.value.max } };
    }
  }
}
function getChartSettings<a>(x: declaration<a>): FunctionChartSettings {
  let range = getRange(x);
  let min = range.floats ? range.floats.min : 0;
  let max = range.floats ? range.floats.max : 10;
  return {
    start: min,
    stop: max,
    count: 20,
  };
}

interface VariableBoxProps {
  heading: string;
  children: React.ReactNode;
  showTypes: boolean;
}

export const VariableBox: React.FC<VariableBoxProps> = ({
  heading = "Error",
  children,
  showTypes = false,
}: VariableBoxProps) => {
  if (showTypes) {
    return (
      <div className="bg-white border border-grey-200 m-2">
        <div className="border-b border-grey-200 p-3">
          <h3>{heading}</h3>
        </div>
        <div className="p-3">{children}</div>
      </div>
    );
  } else {
    return <div>{children}</div>;
  }
};

export interface SquiggleItemProps {
  /** The input string for squiggle */
  expression: squiggleExpression;
  width?: number;
  height: number;
  /** Whether to show a summary of statistics for distributions */
  showSummary: boolean;
  /** Whether to show type information */
  showTypes: boolean;
  /** Whether to show users graph controls (scale etc) */
  showControls: boolean;
  /** Settings for displaying functions */
  chartSettings: FunctionChartSettings;
  /** Environment for further function executions */
  environment: environment;
}

const SquiggleItem: React.FC<SquiggleItemProps> = ({
  expression,
  width,
  height,
  showSummary,
  showTypes = false,
  showControls = false,
  chartSettings,
  environment,
}: SquiggleItemProps) => {
  switch (expression.tag) {
    case "number":
      return (
        <VariableBox heading="Number" showTypes={showTypes}>
          <NumberShower precision={3} number={expression.value} />
        </VariableBox>
      );
    case "distribution": {
      let distType = expression.value.type();
      return (
        <VariableBox
          heading={`Distribution (${distType})`}
          showTypes={showTypes}
        >
          {distType === "Symbolic" && showTypes ? (
            <>
              <div>{expression.value.toString()}</div>
            </>
          ) : (
            <></>
          )}
          <DistributionChart
            distribution={expression.value}
            height={height}
            width={width}
            showSummary={showSummary}
            showControls={showControls}
          />
        </VariableBox>
      );
    }
    case "string":
      return (
        <VariableBox
          heading="String"
          showTypes={showTypes}
        >{`"${expression.value}"`}</VariableBox>
      );
    case "boolean":
      return (
        <VariableBox heading="Boolean" showTypes={showTypes}>
          {expression.value.toString()}
        </VariableBox>
      );
    case "symbol":
      return (
        <VariableBox heading="Symbol" showTypes={showTypes}>
          {expression.value}
        </VariableBox>
      );
    case "call":
      return (
        <VariableBox heading="Call" showTypes={showTypes}>
          {expression.value}
        </VariableBox>
      );
    case "array":
      return (
        <VariableBox heading="Array" showTypes={showTypes}>
          {expression.value.map((r, i) => (
            <SquiggleItem
              key={i}
              expression={r}
              width={width !== undefined ? width - 20 : width}
              height={50}
              showTypes={showTypes}
              showControls={showControls}
              chartSettings={chartSettings}
              environment={environment}
              showSummary={showSummary}
            />
          ))}
        </VariableBox>
      );
    case "record":
      return (
        <VariableBox heading="Record" showTypes={showTypes}>
          {Object.entries(expression.value).map(([key, r]) => (
            <div key={key}>
              <h3>{key}</h3>
              <SquiggleItem
                expression={r}
                width={width !== undefined ? width - 20 : width}
                height={height / 3}
                showTypes={showTypes}
                showSummary={showSummary}
                showControls={showControls}
                chartSettings={chartSettings}
                environment={environment}
              />
            </div>
          ))}
        </VariableBox>
      );
    case "arraystring":
      return (
        <VariableBox heading="Array String" showTypes={showTypes}>
          {expression.value.map((r) => `"${r}"`).join(", ")}
        </VariableBox>
      );
    case "date":
      return (
        <VariableBox heading="Date" showTypes={showTypes}>
          {expression.value.toDateString()}
        </VariableBox>
      );
    case "timeDuration": {
      return (
        <VariableBox heading="Time Duration" showTypes={showTypes}>
          <NumberShower precision={3} number={expression.value} />
        </VariableBox>
      );
    }
    case "lambda":
      return (
        <VariableBox heading="Function" showTypes={showTypes}>
          <FunctionChart
            fn={expression.value}
            chartSettings={chartSettings}
            height={height}
            environment={{
              sampleCount: environment.sampleCount / 10,
              xyPointLength: environment.xyPointLength / 10,
            }}
          />
        </VariableBox>
      );
    case "lambdaDeclaration": {
      return (
        <VariableBox heading="Function Declaration" showTypes={showTypes}>
          <FunctionChart
            fn={expression.value.fn}
            chartSettings={getChartSettings(expression.value)}
            height={height}
            environment={{
              sampleCount: environment.sampleCount / 10,
              xyPointLength: environment.xyPointLength / 10,
            }}
          />
        </VariableBox>
      );
    }
    default: {
      return <>Should be unreachable</>;
    }
  }
};

export interface SquiggleChartProps {
  /** The input string for squiggle */
  squiggleString?: string;
  /** If the output requires monte carlo sampling, the amount of samples */
  sampleCount?: number;
  /** The amount of points returned to draw the distribution */
  environment?: environment;
  /** If the result is a function, where the function starts, ends and the amount of stops */
  chartSettings?: FunctionChartSettings;
  /** When the environment changes */
  onChange?(expr: squiggleExpression): void;
  /** CSS width of the element */
  width?: number;
  height?: number;
  /** Bindings of previous variables declared */
  bindings?: bindings;
  /** JS imported parameters */
  jsImports?: jsImports;
  /** Whether to show a summary of the distirbution */
  showSummary?: boolean;
  /** Whether to show type information about returns, default false */
  showTypes?: boolean;
  /** Whether to show graph controls (scale etc)*/
  showControls?: boolean;
}

let defaultChartSettings = { start: 0, stop: 10, count: 20 };

export const SquiggleChart: React.FC<SquiggleChartProps> = ({
  squiggleString = "",
  environment,
  onChange = () => {},
  height = 200,
  bindings = defaultBindings,
  jsImports = defaultImports,
  showSummary = false,
  width,
  showTypes = false,
  showControls = false,
  chartSettings = defaultChartSettings,
}: SquiggleChartProps) => {
  let expressionResult = run(squiggleString, bindings, environment, jsImports);
  let e = environment ? environment : defaultEnvironment;
  let internal: JSX.Element;
  if (expressionResult.tag === "Ok") {
    let expression = expressionResult.value;
    onChange(expression);
    internal = (
      <SquiggleItem
        expression={expression}
        width={width}
        height={height}
        showSummary={showSummary}
        showTypes={showTypes}
        showControls={showControls}
        chartSettings={chartSettings}
        environment={e}
      />
    );
  } else {
    internal = (
      <ErrorBox heading={"Parse Error"}>
        {errorValueToString(expressionResult.value)}
      </ErrorBox>
    );
  }
  return internal;
};
