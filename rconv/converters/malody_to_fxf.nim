import std/[strformat]

import ../common
import ../fxf as fxf
import ../malody as malody

func convertMalodyToFXF*(chart: malody.Chart): fxf.ChartFile =
    if (chart.meta.mode != malody.ChartMode.Pad):
        raise newException(ValueError, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {chart.meta.mode}, where a {malody.ChartMode.Pad} is required!")

    # TODO: Implement