## Task

1. Take an existing frontend, and properly integrate it into the backend to achieve {task}
2. Use the following rules to achieve your goal

## InitialData

### Replace

Replace mockData with data passed down from Rails as props

```tsx
const mockDatasources = [
  {
    id: 1,
    name: "Customer Data Lake",
    type: "s3",
    bucket: "customer-data-lake",
    prefix: "raw/customers/",
    region: "us-east-1",
    lastSync: "2024-03-10T15:30:00Z",
    status: "active",
  },
  {
    id: 2,
    name: "Product Analytics",
    type: "s3",
    bucket: "analytics-warehouse",
    prefix: "product/events/",
    region: "us-west-2",
    lastSync: "2024-03-09T12:00:00Z",
    status: "active",
  },
];
```

### With

```ruby
def index
  datasources = EasyML::Datasource.where(datasource_type: :s3)

  render inertia: "pages/DatasourcesPage", props: {
    datasources: datasources.map(&:as_json)
  }
end
```

```tsx
interface Datasource {
  datasource: {
    name: string,
    s3_bucket: string,
    s3_prefix: string,
    s3_region: string,
  }
}

export default function DatasourcesPage({ datasources }: { datasources: Datasource }) {
```

### Ensure

1. Use Typescript type definitions
2. Nest data types (e.g. `{datasource: { s3_bucket: "bucket" }}` as required by Rails convention)
3. Check the appropriate model file for a database annotation containing the appropriate columns that will be returned from JSON

## Navigating To New Pages

### Replace

```tsx
useNavigate("page");
```

### With

```tsx
import { router } from "@inertiajs/react";

router.visit("page");
```

### Ensure

You get the rootURL (aka `rootPath`) from `usePage`:

```tsx
import { router, usePage } from "@inertiajs/react";
const { rootPath, url } = usePage().props;
router.visit(`${rootPath}/page`);
```

**NOTICE: You do NOT need to pass rootPath to the frontend, as it is already passed by ApplicationController.**

## Creating Links

### Replace

```tsx
import { Link } from “react-router-dom”
<Link
  to={'location'}
>
  {children}
</Link>
```

### With

```tsx
import { Link } from "@inertiajs/react";
<Link
  href={'location'}
  {children}
</Link>
```

### Ensure

You get the rootURL (aka `rootPath`) from `usePage`:

```tsx
import { router, Link } from "@inertiajs/react";
const { rootPath, url } = usePage().props;
<Link href={`${rootPath}/location`}></Link>;
```

## Form Data

### Replace

```tsx
import React, { useState, useEffect } from "react";

const [formData, setFormData] = useState({
  name: initialData?.name || "",
  modelType: initialData?.modelType || "xgboost",
  datasetId: initialData?.datasetId || "",
  task: initialData?.task || "classification",
  objective: initialData?.objective || "binary:logistic",
  metrics: initialData?.metrics || ["accuracy"],
});
```

### With

```tsx
import { useInertiaForm } from "use-inertia-form";

const { data, setData, post, processing, errors } = useInertiaForm<Model>({
  model: {
    name: "",
    modelType: "",
    datasetId: null,
    task: "regression",
    objective: "reg:squarederror",
    metrics: ["accuracy"],
  },
});
```

### Ensure

- Define Typescript Interfaces using nested attributes to conform to Rails standards

```tsx
interface Model {
  model: {
    name: string,
    modelType: string,
    .. etc..
  }
}
```

- SetData using nested attribute names:

```tsx
onChange={(e) =>
  setData('model.name', e.target.value)
}
```

## Constants, Allowed Settings For Form Data

### Replace

Replace constants defined on the frontend (typescript) with constants provided by the backend APIs

```tsx
const TIMEZONES = [
  { value: 'America/New_York', label: 'Eastern Time' },
  { value: 'America/Chicago', label: 'Central Time' },
  { value: 'America/Denver', label: 'Mountain Time' },
  { value: 'America/Los_Angeles', label: 'Pacific Time' }
];
export default function SettingsPage({ settings: initialSettings }: { settings: Settings }) {
```

### With

- Be sure to follow object-oriented principles, where subclasses might implement constants that their parent classes do not. The main class should respond to `constants`, which will return the constants for all classes + subclasses.

```tsx
class Settings < ActiveRecord::Base
  TIMEZONES = [
    { value: "America/New_York", label: "Eastern Time" },
    { value: "America/Chicago", label: "Central Time" },
    { value: "America/Denver", label: "Mountain Time" },
    { value: "America/Los_Angeles", label: "Pacific Time" }
  ]

  def self.constants
    {
      TIMEZONES: TIMEZONES
    }
  end
end

# Example with subclasses:

class Datasource < ActiveRecord::Base
  DATASOURCE_TYPES = [
    {
      value: "s3",
      label: "Amazon S3",
      description: "Connect to data stored in Amazon Simple Storage Service (S3) buckets"
    }
  ].freeze

  def self.constants
    {
      DATASOURCE_TYPES: DATASOURCE_TYPES,
    }
  end
end

# app/options/datasource_options.rb
module EasyML
  module DatasourceOptions
    def self.constants
      EasyML::Datasource.constants.merge!(
        s3: EasyML::S3Datasource.constants, # Add subclass constants
      )
    end
  end
end
```

```ruby
def edit
  @settings = Settings.first_or_create
  render inertia: "pages/SettingsPage", props: {
    settings: { settings: @settings.as_json },
    constants: SettingsOptions.constants
  }
end
```

```tsx
interface Props {
  constants: {
    TIMEZONES: Array<{ value: string, label: string }>,
  }
}

export default function NewDatasourcePage({ constants }: Props) {
```

### Ensure

- Constants should be defined at the model level, using the format `{ value: 'value', label: 'label' }` as required by frontends

## Form Submission

### Replace

```tsx
const handleSubmit = (e: React.FormEvent) => {
  e.preventDefault();
  onSubmit(formData);
};
```

### With

```tsx
import { useInertiaForm } from "use-inertia-form";

const form = useInertiaForm<Settings>({
  settings: {
    timezone: initialSettings?.settings?.timezone || "America/New_York",
    s3_bucket: initialSettings?.settings?.s3_bucket || "",
    s3_region: initialSettings?.settings?.s3_region || "us-east-1",
    s3_access_key_id: initialSettings?.settings?.s3_access_key_id || "",
    s3_secret_access_key: initialSettings?.settings?.s3_secret_access_key || "",
  },
});
const { data: formData, setData: setFormData, patch, processing } = form;
const handleSubmit = (e: React.FormEvent) => {
  e.preventDefault();
  setSaved(false);
  setError(null);

  const timeoutId = setTimeout(() => {
    setError("Request timed out. Please try again.");
  }, 3000);

  patch(`${rootPath}/settings`, {
    onSuccess: () => {
      clearTimeout(timeoutId);
      setSaved(true);
    },
    onError: () => {
      clearTimeout(timeoutId);
      setError("Failed to save settings. Please try again.");
    },
  });
};
```

### Ensure

- Ensure all edge cases are fleshed out, including validations, timeouts, success, and error cases.

## Alerts

- Alerts will appear automatically if you use `flash.now[:notice]` for success statements and `flash.now[:error]` for error statements
- For model validation errors, prefer inline errors

## Controller Actions

### Use Inertia Rails

```ruby
def edit
  datasource = EasyML::Datasource.find_by(id: params[:id])

  render inertia: "pages/EditDatasourcePage", props: {
    datasource: {
      id: datasource.id,
      name: datasource.name,
      s3_bucket: datasource.s3_bucket,
      s3_prefix: datasource.s3_prefix,
      s3_region: datasource.s3_region
    },
    constants: EasyML::DatasourceOptions.constants
  }
end
```
