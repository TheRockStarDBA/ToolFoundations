[![Build status](https://ci.appveyor.com/api/projects/status/q38mor7o20ejxswx?svg=true)](https://ci.appveyor.com/project/alx9r/a9foundations)

## a9Foundations

a9Foundations is a collection of PowerShell helper functions that I commonly use when writing other Powershell cmdlets in Powershell:

* [`Get-BoundParams`](./Functions/cmdlet.ps1) - a terse way to get the current cmdlet's bound parameters.
* [`Get-CommonParams`](./Functions/cmdlet.ps1) - a terse way to reliably cascade common parameters (like `-Verbose`) from one cmdlet to another
* [`Out-Collection`](./Functions/collection.ps1) - reliably transmit collections through the PowerShell pipeline without loop unrolling
* [`Compare-Object2`](./Functions/compareObject2.ps1) - like `Compare-Object` but accepts Null without throwing and keeps `Passthru` objects separate instead of merging them into a single one-dimensional array
* [`Invoke-Ternary`](./Functions/invoke.ps1) - the `?:` operator with behavior enforced by unit tests
* [`Expand-String`](./Functions/string.ps1) - terse delayed expansion of variables in strings

## Compatibility

PowerShell Version | Compatible         | Remarks
-------------------|--------------------|--------
2.0                | :white_check_mark: | there are [some PowerShell 2 limitations](https://github.com/alx9r/a9Foundations/labels/Powershell%202%20Limitation)
3.0                | :grey_question:    | not tested, probably works
4.0                | :white_check_mark: |
5.0                | :white_check_mark: |
