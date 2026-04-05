{{- define "argocd-example-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "argocd-example-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "argocd-example-app.name" . | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "argocd-example-app.labels" -}}
app.kubernetes.io/name: {{ include "argocd-example-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
