# -*- mode: Python -*-

# Ente Photos Local Development with Tilt
# ========================================
# Deploys the Ente Helm chart to a local orbstack K8s cluster.
# Builds server and web images locally for fast iteration.
#
# Prerequisites:
#   - orbstack running with K8s enabled (context: orbstack)
#   - CNPG operator installed
#   - 'dev' namespace exists: kubectl create namespace dev
#   - Tilt installed: brew install tilt
#
# Usage:
#   tilt up

allow_k8s_contexts('orbstack')

load('ext://namespace', 'namespace_create')
load('ext://helm_resource', 'helm_resource')
namespace_create('dev')

# Mailpit — local email catcher (UI at http://localhost:8025)
# Docs: https://mailpit.axllent.org
# Chart: https://github.com/jouve/charts/tree/main/charts/mailpit
local('helm repo add jouve https://jouve.github.io/charts/ >/dev/null 2>&1 || true')
helm_resource(
    'mailpit',
    'jouve/mailpit',
    namespace='dev',
    flags=['--set=fullnameOverride=mailpit'],
    port_forwards=[port_forward(8025, 8025, name='Mailpit UI')],
    labels=['infra'],
)

HELM_CHART_PATH = '/Users/jeremy/code/pianobase/helm-charts/charts/ente'

# Build museum server image from server/ directory
docker_build(
    'ente-museum-dev',
    context='./server',
    dockerfile='./server/Dockerfile',
    only=[
        'cmd/',
        'ente/',
        'internal/',
        'pkg/',
        'configurations/',
        'migrations/',
        'mail-templates/',
        'web-templates/',
        'config/',
        'tools/',
        'go.mod',
        'go.sum',
        'Dockerfile',
    ],
    live_update=[
        sync('./server/configurations/', '/configurations/'),
    ],
)

# Build web frontend image (all apps: photos, auth, accounts, cast, share, embed, memories, paste)
# Context is repo root — Dockerfile copies web/ and rust/core/
docker_build(
    'ente-web-dev',
    context='.',
    dockerfile='./web/Dockerfile',
    only=[
        'web/',
        'rust/.cargo/',
        'rust/contacts/',
        'rust/core/',
    ],
)

# Deploy via Helm — layer local-dev.yaml on top of values-dev.yaml
IMAGE_SET = [
    'museum.image.repository=ente-museum-dev',
    'museum.image.tag=latest',
    'museum.image.pullPolicy=IfNotPresent',
]

# All frontend services share the same web image
FRONTEND_SERVICES = ['photos', 'auth', 'accounts', 'share', 'embed', 'paste', 'memories', 'cast']
for svc in FRONTEND_SERVICES:
    IMAGE_SET += [
        '%s.image.repository=ente-web-dev' % svc,
        '%s.image.tag=latest' % svc,
        '%s.image.pullPolicy=IfNotPresent' % svc,
    ]

k8s_yaml(
    helm(
        HELM_CHART_PATH,
        name='ente',
        namespace='dev',
        values=[
            # HELM_CHART_PATH + '/values-dev.yaml',
            './local-dev.yaml',
        ],
        set=IMAGE_SET,
    )
)

# Museum server: port-forward for direct API access
k8s_resource(
    'ente-museum',
    port_forwards=[
        port_forward(8080, 8080, name='Museum API'),
    ],
    labels=['backend'],
)

# Frontend services with port-forwards
k8s_resource('ente-photos',    port_forwards=[port_forward(3000, 3000, name='Photos')],    labels=['frontend'])
k8s_resource('ente-accounts',  port_forwards=[port_forward(3001, 3001, name='Accounts')],  labels=['frontend'])
k8s_resource('ente-auth',      port_forwards=[port_forward(3003, 3003, name='Auth')],      labels=['frontend'])
k8s_resource('ente-cast',      port_forwards=[port_forward(3004, 3004, name='Cast')],      labels=['frontend'])
k8s_resource('ente-share',     port_forwards=[port_forward(3005, 3005, name='Share')],     labels=['frontend'])
k8s_resource('ente-embed',     port_forwards=[port_forward(3006, 3006, name='Embed')],     labels=['frontend'])
k8s_resource('ente-memories',  port_forwards=[port_forward(3007, 3007, name='Memories')],  labels=['frontend'])
k8s_resource('ente-paste',     port_forwards=[port_forward(3008, 3008, name='Paste')],     labels=['frontend'])
