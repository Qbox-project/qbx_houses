# qb-houses
Real Estate for QB-Core Framework :house_with_garden:

## Dependencies
- [qb-core](https://github.com/Qbox-project/qb-core)
- [qb-radialmenu](https://github.com/Qbox-project/qb-radialmenu) - For the menu in screenshots
- [qb-phone](https://github.com/Qbox-project/qb-phone) - Houses app
- [qb-multicharacter](https://github.com/Qbox-project/qb-multicharacter) - Checking if player is inside after character chosen (You need to edit the lines if you don't use this)
- [qb-garages](https://github.com/Qbox-project/qb-garages) - House Garage
- [qb-interior](https://github.com/Qbox-project/qb-interior) - Necessary for house interiors
- [qb-clothing](https://github.com/Qbox-project/qb-clothing) - Outfits
- [qb-weathersync](https://github.com/Qbox-project/qb-weathersync) - Desync weather inside house
- [qb-weed](https://github.com/Qbox-project/qb-weed) - Weed plant
- [qb-skillbar](https://github.com/Qbox-project/qb-skillbar) - Skills

## Screenshots
![Buy House](https://imgur.com/4eQnRqA.png)
![House Door](https://imgur.com/UQzvdzn.png)
![Garage](https://imgur.com/XRbkzsP.png)
![Radial Menu](https://imgur.com/GTpalYW.png)
![Decorate](https://imgur.com/Bbp6rvI.png)
![Object Placing](https://imgur.com/fmV0gPM.png)
![Stash](https://imgur.com/HarcCIU.png)
![Inside Door](https://imgur.com/Y0rzBuy.png)
![Security Camera](https://imgur.com/a0qPwsL.png)

# House Tiers
## T1
![Tier 1](https://i.imgur.com/pLVzo6G.jpg)
![Tier 1](https://i.imgur.com/YqZHjra.jpg)
## T2
![Tier 2](https://i.imgur.com/mp3XL4Y.jpg)
![Tier 2](https://i.imgur.com/3DH9RFw.jpg)
## T3
![Tier 3](https://i.imgur.com/1XF60jD.jpg)
![Tier 3](https://i.imgur.com/iVYajrY.jpg)
## T4
![Tier 4](https://i.imgur.com/ubt165o.jpg)
![Tier 4](https://i.imgur.com/x5nXid5.jpg)
## T5
![Tier 5](https://i.imgur.com/CbqPcq0.jpg)
![Tier 5](https://i.imgur.com/RxKlteo.jpg)
## T6
![Tier 6](https://i.imgur.com/pRS6XdN.jpg)
![Tier 6](https://i.imgur.com/sNFavws.jpg)

## Features
- Stormram for police
- House garage
- Adding houses in-game with command (See commands section below)
- House decoration
- Key system
- Outfits
- Stash
- Real Estate Job
- Different interiors based on house tier
- Doorbell
- Automatically adds blip for owned house

### Commands
- /decorate - Allows the player decorate the house
- /createhouse [price] [tier] - Creates a house and saves it to database (Only people with "realestate" job)
- /addgarage - Adds a garage to nearby house (Only people with "realestate" job)
- /enter - Enters the nearby house (keys needed)
- /ring - Rings the bell of nearby house

## Installation
### Manual
- Download the script and put it in the `[qb]` directory.
- Import `qb-houses.sql` in your database
- Add the following code to your server.cfg/resouces.cfg
```
ensure qb-core
ensure qb-radialmenu
ensure qb-anticheat
ensure qb-phone
ensure qb-multicharacter
ensure qb-garages
ensure qb-interior
ensure qb-clothing
ensure qb-weathersync
ensure qb-weed
ensure qb-skillbar
```