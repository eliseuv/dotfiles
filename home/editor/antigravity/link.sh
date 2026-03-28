#!/bin/sh

ln --symbolic "$(realpath ./settings.json)" ~/.config/Antigravity/User/settings.json

ln --symbolic "$(realpath ./extensions.json)" ~/.antigravity/extensions/extensions.json
