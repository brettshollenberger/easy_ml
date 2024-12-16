import React from "react";
import { Settings2 } from "lucide-react";
import { Popover } from "../Popover";

export function FeatureConfigPopover() {
  return (
    <Popover
      trigger={
        <button
          type="button"
          className="p-2 text-gray-400 hover:text-gray-600"
          title="Configure transforms"
        >
          <Settings2 className="w-5 h-5" />
        </button>
      }
      className="w-96"
    >
      <div className="space-y-4">
        <p className="text-sm text-gray-600">
          Feature options can be configured in the codebase, and loaded in
          initializers:
        </p>

        <div className="bg-gray-50 p-3 rounded-md">
          <code className="text-sm text-gray-800">
            config/initializers/transforms.rb
          </code>
        </div>

        <p className="text-sm text-gray-600">Example feature implementation:</p>

        <pre className="bg-gray-50 p-3 rounded-md overflow-x-auto">
          <code className="text-xs text-gray-800">
            {`# lib/transforms/did_convert.rb
module Features
  class DidConvert
    include EasyML::Features

    def did_convert(df)
      df.with_column(
        (Polars.col("rev") > 0)
          .alias("did_convert")
      )
    end
    
    feature :did_convert,
      name: "Did Convert",
      description: "Boolean true/false..."
  end
end`}
          </code>
        </pre>
      </div>
    </Popover>
  );
}
