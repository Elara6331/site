+++
title = "LURE"
date = "2023-02-12"
showSummary = true
summary = "Distro-agnostic AUR-like build system for Linux"
weight = 30
+++

## About

[LURE](https://lure.arsenm.dev/) is a major project that I am currently working on. It allows Linux users to install software not otherwise available in their distro's repositories. It functions in a similar manner to Arch Linux's AUR, but works for any supported distro.

## How it works

LURE uses various techniques to abstract package formats and package managers, enabling the creation and installation of packages automatically built from bash scripts similar to the AUR's PKGBUILD scripts. It uses the package manager already present on the system, making it possible to manage LURE packages as you would any other distro package.

## Motivation

Arch Linux has a feature called the AUR, which allows any user to submit a package for other users to install. This means any user interested in a piece of software can package it for everyone, providing a repository of just about any software one could want to install. I feel this feature shouldn't be constrained to just Arch Linux, and should be available for everyone to use, allowing people to install software with a complicated install procedure, without having to worry about performing that procedure, as LURE handles it automatically.

## Problems with this approach

As has been rightfully pointed out by several people, trying to handle the various differences between the software available on each distro, especially library versions, is very difficult. This is not a problem LURE intends to solve. It simply provides a way for developers to automate the procedure of installing their software, so that their users don't have to figure it out themselves. This means that developers will have to handle some of those differences, such as dependency naming. However, LURE will help wherever it can, providing helper commands to create packages that adhere to the guidelines of the distro the package is being built for.