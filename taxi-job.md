# Feature Showcase: Taxi job

Source: GTA World Forums - GTA V Heavy Roleplay Server (Features Showcase).

## Commands

- `/taxi` - Call for a taxi. On-duty taxi drivers receive a notification about the request.
- `/taxistart` - Go on duty as a taxi driver.
- `/taxistop` - Go off duty as a taxi driver.
- `/taxiaccept` - Accept a request when you're on duty as a taxi driver.
- `/taxicancel` - Cancel the request (customer) or cancel the accepted request (driver). Both the customer and driver are informed.
- `/taxidone` - Taxi driver finishes the accepted request.
- `/fare [amount]` - Set the taxi fare. Default is $10, must be between $1 and $100.
- `/taxirent` - Extend the rental time for the rented taxi.
- `/stoptaxirent` - Stop renting the taxi.

## Job information

### Requirements

Before you can start working as a taxi driver, there are a few requirements:

1. Obtain a valid taxi license at the License Registration.
2. Get a taxi vehicle. You can either buy one or rent one for 30 minutes at Downtown Cab Co. (taxi rental section).

### Location for taxi license

![Location for taxi license](3W01Kh4.jpg)

### Location Downtown Cab Co. & taxi rental

![Location Downtown Cab Co. & taxi rental](hp8JzEi.jpg)

## Taxi requests

Once you are on duty, you will receive incoming/pending calls. When a call comes in, the taxi driver receives a notification about who is requesting the call. After accepting the request, the driver receives the phone number and the GPS location is automatically set to the customer.

Note: the GPS coordinates will be at the location from which the customer called, not where the customer currently is.

Rules and notes:

- A player can only make one taxi request at a time.
- A taxi driver can only accept one request at a time.
- An accepted request can be cancelled by both the taxi driver and the customer.

If the player sets a waypoint on their map, it will automatically update/set the waypoint for the taxi driver.

### Request notifications for the driver

![Request notification 1](rwNculq.jpg)

![Request notification 2](MaUe2dH.jpg)

### Request information after accepting

![Request information](1qgx34f.jpg)

## Fare

The taxi driver can set the fare between $1 and $100, with a default fare of $10. The taxi meter can be started and stopped by the taxi driver using commands. If the taxi is not moving, the fare automatically pauses.

![Taxi fare meter](8bQgB2t.png)

Note: money is not automatically taken from the player; you must roleplay the payment.

## Taxi rental

If a player doesn't want to buy a taxi or doesn't have the cash, they can rent a vehicle at Downtown Cab Co. for 30 minutes for $300.

- A reminder is shown when remaining time is 1 and 5 minutes.
- When 5 minutes or less remain, the player can add another 30 minutes.
- Extending time adds 30 minutes and does not replace remaining time.
- The player can stop the rental before the time ends.

![Taxi rental](jLlJc6c.jpg)

## Fees

There are two types of fees: towing fees and damage fees.

- If a rented taxi is not returned to the spawn location, a $300 towing fee is charged.
- If a rented taxi is returned damaged or destroyed, a $250 damage fee is charged.

Fees are registered in player debts and are deducted upon paycheck or can be paid sooner using `/paydebts`.

## Temporary saved data

All taxi driver data is stored for 10 minutes. This gives the player enough time to reconnect and continue their roleplay. If the player doesn't return within 10 minutes, the data is lost and they must start the job over.

---

Original post date: November 24, 2017 (edited April 21, 2019).
