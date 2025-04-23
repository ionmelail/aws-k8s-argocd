#!/bin/bash
set -e

ARGOCD_SERVER="localhost:8085"
ARGOCD_USER="admin"
ARGOCD_PASS="password"

echo "🔐 Logging into ArgoCD via port-forward..."
argocd login $ARGOCD_SERVER --username $ARGOCD_USER --password $ARGOCD_PASS --insecure

echo "🔧 Verifying 'default' project exists..."
if ! argocd proj get default --server=$ARGOCD_SERVER; then
  argocd proj create default --server=$ARGOCD_SERVER
fi

echo "🔧 Ensuring 'admin' role exists..."
if ! argocd proj role list default --server=$ARGOCD_SERVER | grep -q "admin"; then
  argocd proj role create default admin --server=$ARGOCD_SERVER
fi

echo "🔐 Assigning permissions to 'admin' role..."
argocd proj role add-policy default admin -a get -o applications/* -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a sync -o applications/* -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a update -o applications/* -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a override -o applications/* -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a create -o applications/* -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a delete -o applications/* -p allow --server=$ARGOCD_SERVER

argocd proj role add-policy default admin -a get -o projects/default -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a update -o projects/default -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a sync -o projects/default -p allow --server=$ARGOCD_SERVER
argocd proj role add-policy default admin -a override -o projects/default -p allow --server=$ARGOCD_SERVER

argocd proj allow-cluster-resource default "*" "*" --server=$ARGOCD_SERVER
argocd proj allow-namespace-resource default "*" "*" --server=$ARGOCD_SERVER

echo "✅ RBAC configuration for 'admin' in ArgoCD completed."
