#!/bin/bash
sudo kubectl -n argocd port-forward svc/argocd-server 7000:443