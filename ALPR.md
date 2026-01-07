# LSPD Automatic License-Plate Recognition

## Feature showcase

**Author:** -Andreas

## Overview

Automatic License-Plate Recognition (ALPR) is a system installed in a small set of
LSPD Traffic Division cruisers. The system simulates cameras mounted on the front
of the cruiser and periodically scans vehicles in front of the car. It only works
within 20 meters.

![ALPR logo](logot.png)

When a vehicle is detected, the system runs a database search that takes about
four seconds. After a beep, it displays information about the vehicle, including
registration, whether the owner has a driver’s license, stolen status, and road
tax delinquencies.

![ALPR scan](BQIRTpL.jpg)

To make the display easy to read, results are paired with triangles and color
coding to highlight issues quickly.

![ALPR alert](8qKC0G0.jpg)

![ALPR UI](ywiq39C.jpg)

## Commands

- `/alpr`: Toggle the system on/off.
- `/reportvehiclestolen` (`/reportvehstolen`, `/reportstolen`) `[numberplate]`:
  Report your vehicle stolen so ALPR flags it.
- `/reportvehiclefound` (`/reportvehfound`, `/reportfound`) `[numberplate]`:
  Report your vehicle found again. Stolen vehicle reports reset after a server
  restart.
