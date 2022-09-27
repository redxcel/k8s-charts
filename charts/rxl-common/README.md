# rxl-common

A helper chart used by most of our other charts

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: library](https://img.shields.io/badge/Type-library-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

**This chart is a [Library Chart](https://helm.sh/docs/topics/library_charts/)** -
this means that the chart itself deploys no resources, and has no `.yaml`
template files. Instead the intention is for this chart to be included inside
another chart, and the functions that it exposes are then available for use.

## [Common Functions](templates/_common.tpl)

These common functions are the most basic functions that you tend to need in
Helm charts - labels, selectorLabels, release name, etc.

### Values Parameters

* `.Values.nameOverride`: Optional string used to control the name of the
  chart, and most of the chart resources.
* `.Values.fullnameOverride`: Optional string used to completely rename the
  prefix for all of the chart resources. Using this will avoid any other values
  going into the chart resource names, giving you complete control.
* `.Values.podLabels`: List of labels to be applied to the Pods
* `.Values.serviceAccount.create`
* `.Values.serviceAccount.name`
* `.Values.image.repository`
* `.Values.image.tag`
* `.Values.image.forceTag`

### `rxl-common.name`

Expands the name of the chart (`.Chart.Name`), or optionally returns an
override of the string from `.Values.nameOverride`. This is mostly used for
building our other labels and annotations.

_Example Usage_:
```yaml
app.kubernetes.io/name: {{ include "rxl-common.name" . }}
```

### `rxl-common.chart`

Expands out the name of the chart (`.Chart.Name`) and the version of the chart
(`.Chart.Version`), used for setting the `helm.sh/chart` label.

_Example Usage_:
```yaml
helm.sh/chart: {{ include "rxl-common.chart" . }}
```

### `rxl-common.fullname`

Expands out the name of the chart, along with the name of the release to create
a DNS-compatible set of resource names. ptionally, if
`.Values.fullnameOverride` is set, then that value is used instead of any of
the other values as the resource prefix.

_Example Usage_:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "rxl-common.fullname" . }}
  ...
```

### `rxl-common.containerName`

Returns the name of the application container which by default
is set to (`.Chart.Name`), or optionally returns an override of
the string from `.Values.containerName`. This is mostly used for
specifying application container name.

_Example Usage_:
```yaml
apiVersion: v1
kind: Deployment
metadata:
  name: {{ include "rxl-common.fullname" . }}
spec:
  template:
    spec:
      containers:
        - name: {{ include "rxl-common.containerName" . }}
  ...
```

### `rxl-common.labels`

Creates a set of common and reasonable labels applied to most of the resources
in the chart. The Kubernetes team has defined [common
labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels)
that we use, and we add in a few of our own as well.

### `rxl-common.serviceAccountName`

Returns the name of the ServiceAccount that should be used by the pods in your
application. Has two modes - one mode where you have decided to create the
`ServiceAccount` within your chart, and another where you are leveraging an
already existing `ServiceAccount.

#### Mode 1: Creating the ServiceAccount

As long as `.Values.serviceAccount.create` is set to `true`, then the
`ServiceAccountName` will be set to the output of the `rxl-common.fullname`
function. Alternatively you can override this by setting
`.Values.serviceAccount.name`.

#### Mode 2: Using an existing ServiceAccount

If `.Values.serviceAccount.create` is set to `false`, then `ServiceAccountName`
will be returend as `"default"`, or alternatively whatever value you set in
`.Values.serviceAccount.name`.

### `rxl-common.imageTag`

Returns the target Docker image tag that should be used. Defaults to
`.Values.image.forceTag`, then falls back to `.Values.image.tag` and finally
`.Chart.AppVersion`

### `rxl-common.imageFqdn`

Returns back the fully qualified image name to use for the application. Takes
into account whether or not the image name includes a `sha256:` prefix, and
formats the value appropriately so that Kubernetes is happy.

## [Monitoring Functions](templates/_monitors.tpl)

These functions are specific to setting up monitoring of your application
through Prometheus, Grafana, etc.

### `rxl-common.podMonitor`

This function creates an entire `PodMonitor` resource. All you have to do is
put it into a template:

_Example Usage_:
```yaml
# templates/podmonitor.yaml
{{- include "rxl-common.podMonitor" . }}
```

## [TopologySpreadConstraint Functions](templates/_topology_spread_constraints.tpl)

This common function creates some sane `TopologySpreadConstraint` settings in a
PodSpec. The default behavior can be turned on with a simple boolean flag,
which spreads pods across AZs. More custom topologies can be described as well.

### Values Parameters

* `.Values.topologySpreadConstraints`: A list of maps that conform to the
    [`TopologySpreadConstraint` API](https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/#api).
* `.Values.enableTopologySpread`: A boolean to control the creation of the
    "default" topology spread constraint across AZs.
* `.Values.topologyKey`: The default `topologyKey` to use when the
    `enableTopologySpread` boolean flag is enabled.
* `.Values.topologySkew`: The default `maxSkew` to use when
    `enableTopologySpread` boolean flag is enabled.

### `rxl-common.topologySpreadConstraints`

_Example Usage_:
```yaml

{{- if or .Values.topologySpreadConstraints .Values.enableTopologySpread }}
topologySpreadConstraints:
  {{- include "rxl-common.topologySpreadConstraints" . | nindent 8 }}
{{- end }}

```

## [Network Functions](templates/_networkpolicy.tpl)

These functions are focused around providing network-level access into the
resources within your namespace, or controlling the network permissions in
other ways.

### Values Parameters

Each of the functions in the
[`templates/_networkpolicy.tpl`](templates/_networkpolicy.tpl) functions file
look for particularly named value keys. In particular:

* `.Values.ports`: This must be a list of maps that contain `containerPort` and `protocol` keys.
* `.Values.network.allowedNamespace`: This is a list of strings that represent
  `Namespaces` that you want to grant access into your service.

### `rxl-common.networkPolicy`

This function creates a `NetworkPolicy` resource that grants access into the
Pods running in your namespace. The ports are picked from the `.Values.ports`
key, and the clients are listed by-namespace in the
`.Values.network.allowedNamespace` list of strings.

_Example Usage_:
```yaml
# templates/networkpolicy.yaml
{{- include "rxl-common.networkPolicy" . }}
```

## [Istio Functions](templates/istio.tpl)

### Values Parameters

* `.Values.podLabels`
* `.Values.monitor.path`
* `.Values.monitor.portNumber`

* `.Values.istio.enabled` (default: `True`): Controls whether or not the Istio
  functions are enabled or disabled. Also used in some other monitoring
  functions.

* `.Values.istio.excludeInboundPorts[]` (default: `[]`): If supplied, this is a
  list of TCP ports that are excluded from being proxied by the Istio-proxy
  Envoy sidecar process. _The `.Values.monitor.portNumber` is already included
  by default.

* `.Values.istio.preStopCommand`: A string representing a command that will run
  within the pod before the Istio Envoy sidecar will begin shutting down. This
  setting can be used to ensure that the `envoy` process continues to allow
  traffic to flow while your application begins handling the `SIGTERM` from the
  Kubelet. Eg: `/bin/sleep 30`. _If this is set, then this takes priority over
  the value of `.Values.ports[]` below._

* `.Values.ports[]`: If your application exposes ports, and you do _not_ set a
  `preStopCommand`, then we will configure the `istio-proxy` sidecar to loop
  until it finds no TCP ports in the `LISTENING` state. This is a reasonably
  safe default behavior to ensure that the proxy does not shut down until all
  other traffic has stopped.

* `.Values.istio.metricsMerging`: If set to "True", then the Istio Metrics
  Merging system will be turned on and Envoy will attempt to scrape metrics
  from the application pod and merge them with its own. This defaults to False
  beacuse in most environments we want to explicitly split up the metrics and
  collect Istio metrics separate from Application metrics.

### `rxl-common.istioAnnotations`

There are a number of common [Istio Resource
Annotations](https://istio.io/latest/docs/reference/config/annotations/) that
we want to apply to most of our workloads. These annotations are generally safe
to apply as defaults, and then we have certain `Values` parameters that we can
override to change the behavior when necessary.

_Example Usage_:
```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ...
...
spec:
  template:
    metadata:
      annotations:
        {{- include "rxl-common.istioAnnotations" . | nindent 8 }}
```

### `rxl-common.istioLabels`

This function creates the common labels that Istio uses for routing traffic,
deciding to inject the pods with sidecars, and more. See the [Istio Application
Requirements](https://istio.io/latest/docs/ops/deployment/requirements/) for
more details about the `app` and `version` labels.

_Example Usage_:

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ...
...
spec:
  template:
    metadata:
      labels:
        {{- include "rxl-common.istioLabels" . | nindent 8 }}
```

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)
