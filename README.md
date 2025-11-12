# @simatic-ax.lacyccom

## Description

The following section shows a scenario for a possible application of the LAcycCom
library:

With acyclic data exchange, contrary to cyclic communication, data transfer takes place when an explicit request is made, e.g. in order to read and write drive object parameters. Acyclic parameter access occurs parallel to the cyclic process data exchange. This saves resources, since the data is only requested on demand, i. e. when a parameter has to be transferred.The "Read data record" and "Write data record" services are available for acyclic data exchange.

According to the PROFIdrive profile, for drives in conformance with PROFIdrive, only one DPV1 (asynchronous PROFIBUS communication) request is permissible for each drive object and control unit for non-cyclic (acyclic) communication (parameter requests). If two or more DPV1 requests are simultaneously issued to a drive unit, conflicts can occur when processing the request in the drive unit. These conflicts then cause the different DPV1 requests to mutually interfere with one another. In order to prevent that such bus conflict occurs, it is the user’s responsibility to avoid that and a check must be made for each new DPV1 request whether another request is already active on the drive object involved. This is certainly the case if system functions are also used that are not exclusively intended to communicate to drive units via DPV1 services.

In order to relieve the user of this task a request management called Resource Manager exists that handles the management of DPV1 services for the user. This function is presented here. However, the introduction of this request management assumes as prerequisite that each function, which utilizes DPV1 services, will also actually use them.

## Install this package

Enter:

```cli
apax add @simatic-ax/lacyccom
```

## Namespace

```iec-st
Simatic.Ax.LAcycCom;
```

## Objects

The library contains two main functionalities.

A [docs/resourceManagement.md](resource manager) that handles acyclic resources.

[docs/driveFunctions.md](Blocks for acyclic data exchange) with the SINAMICS drive.

Please refer to their specific documentation pages.

## Example

[docs/appExample.md](Go here for an application example)

## Contribution

Thanks for your interest in contributing. Anybody is free to report bugs, unclear documentation, and other problems regarding this repository in the Issues section or, even better, is free to propose any changes to this repository using Merge Requests.

## License and Legal information

Please read the [Legal information](LICENSE.md)
