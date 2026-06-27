# Devchacha Weed - Advanced Farming System (VORP)

A comprehensive weed farming system for RedM (VORP Core), featuring multi-stage growth, water management, batch processing, and a unique water wagon rental system.

## Features

### 🌿 Advanced Farming
- **3 Unique Strains**: Kalka (Guarma Gold), Purp (Ambarino Frost), Tex (New Austin Haze).
- **Growth Stages**: Seedling -> Young -> Mature.
- **Watering System**: Plants require water. Rent a water wagon or use water buckets.
- **Visuals**: Props scale with growth and change models. Fully grows in **4 minutes** by default.

### 🚜 Water Wagon Rental
- Rent a **Water Wagon** from the Seed Vendor by holding the **R key** ($50).
- Holds **50 Litres** of water.
- Use it to fill your buckets anywhere on the farm by holding the **G key** at the back of the wagon.
- **Refillable**: Drive the wagon into a river/lake and hold the **G key** to "Refill Tank".

### 🏭 Batch Processing
- **Washing**: Wash dirty leaves in the Wash Bucket. **Requires 50x Leaves**. Yields 46-49x Washed.
- **Drying**: Hang washed weed on the Drying Rack. **Requires 50x Washed**. Yields 46-49x Dried.
- **Trimming**: Trim dried buds at the table. **Requires 50x Dried**. Yields 46-49x Trimmed.
- **Loss Mechanic**: You always lose a small percentage during processing to simulate waste.
- **Placed Objects**: All placed processing props (Wash Bucket, Drying Rack) are interactive. Hold the **G key** to process products, or hold the **R key** to Pick Up.

### 💰 Dynamic Selling
- Sell processed weed (Trimmed or Joints) by typing the `/sellweed` command inside city limits.
- Civilian NPC buyers will walk to you one-by-one to negotiate.
- Automatically terminates selling session if you run out of weed or walk outside city limits.

## Configuration

Admins can adjust gameplay mechanics in `config.lua`.

### ⚙️ Main Settings
| Setting | Description | Default |
| :--- | :--- | :--- |
| `Config.GrowthTime` | Time in **minutes** for a plant to fully grow. | `4` |
| `Config.WaterRate` | Water loss per minute. Higher = faster drying. | `10.0` |
| `Config.HarvestAmount` | Range of items received when harvesting. | `{min=2, max=5}` |
| `Config.BucketUses` | How many times a water bucket can be used. | `10` |

### 👮 Police & Legal
| Setting | Description | Default |
| :--- | :--- | :--- |
| `Config.PoliceAlerts` | Enable/Disable alerts for illegal farming/selling. | `true` |
| `chance` | Percentage chance (1-100) to alert law. | `50` |
| `jobs` | List of job keys that receive alerts. | `['police', ...]` |

### 🚬 Smoking Buffs
| Setting | Description | Default |
| :--- | :--- | :--- |
| `jointHealthBoost` | Health restored per joint. | `10` |
| `jointStaminaBoost` | Stamina restored per joint. | `20` |
| `pipePuffs` | Number of puffs a pipe holds. | `10` |

## 💻 Installation

### 1. Dependencies
Ensure these resources are started **before** `devchacha-weed` in your `server.cfg`:
- **VORP Core** - Core Framework
- **VORP Inventory** - Inventory System
- **VORP Progressbar** - Progress Bar System
- **oxmysql** - MySQL Database Library

### 2. Item Setup
Items are registered via SQL. Run `install.sql` to insert all required items into the VORP `items` table automatically.

### 3. Database
**IMPORTANT**: The script does **NOT** create the database table automatically.
1. Locate the `install.sql` file in the main folder of this resource.
2. Open your database manager (HeidiSQL, DBeaver, etc).
3. **Import / Run** the `install.sql` file into your server's database.

### 4. Images
Inventory images are **required** for icons to show up.
1. Go to the `html/img/` folder inside this resource.
2. **Copy** all the `.png` files.
3. **Paste** them into your inventory's image folder:
   - Path: `vorp_inventory/html/images/`

### 5. Final Step
Add the resource to your `server.cfg`:
```cfg
ensure devchacha-weed
```

## 📖 Player Guide

### 🧑‍🌾 Getting Started
1. **Visit the Vendor**: Head to the **Gardening Supplies** blip (near Valentine).
2. **Browse Store**: Hold the **G key** to open the seed shop.
3. **Rent a Water Wagon**: Hold the **R key** to rent a water wagon from the vendor.
4. **Tools You Need**:
   - **Shovel**: For planting and harvesting.
   - **Water Bucket**: Buy an Empty Bucket and fill it at a river, or use the Water Wagon.
   - **Seeds**: Pick your strain (Kalka, Purp, or Tex).
   - **Fertilizer** (Optional): Speeds up growth.

### 🌱 Farming Cycle
1. **Planting**: Find a nice spot of soil and use your seed from your inventory.
2. **Caring**:
   - **Watering**: Plants need water to grow! Use a **Full Bucket** or a **Water Wagon**. Walk near a plant and hold the **G key** to inspect, then select Water.
   - **Fertilizing**: Open the plant menu (Hold G) and click Fertilize to speed up growth.
   - **Growth**: Plants have 3 visual stages. Wait for it to hit 100% (4 minutes default).
3. **Harvesting**: Once fully grown, inspect the plant (Hold G) and click Harvest to gather leaves using your **Shovel**.

### 🚜 Equipment: The Water Wagon
- Rent a **Water Wagon** from the vendor for $50 by holding the **R key**.
- Holds **50 Litres** of water.
- **Refill**: Drive the wagon into a river/lake and hold the **G key** to "Refill Tank".
- **Usage**: Walk to the back of the wagon with an empty bucket and hold the **G key** to fill it.

### 🏭 Processing Your Harvest
Turn your raw leaves into sellable product. You need **50x Items** for each step.
1. **Washing**:
   - Buy and place a **Wash Bucket**.
   - Walk up to it, hold the **G key** and select "Wash Weed".
   - *50x Leaves -> 46-49x Washed Bud*.
2. **Drying**:
   - Buy and place a **Drying Rack**.
   - Walk up to it, hold the **G key** and select "Dry Buds".
   - *50x Washed -> 46-49x Dried Bud*.
3. **Trimming**:
   - Use the **Drying Rack** again.
   - Walk up to it, hold the **G key** and select "Trim Buds".
   - *50x Dried -> 46-49x Trimmed Bud*.

### 💰 Making Money: Street Dealing
Sell your product directly to locals in **Valentine, Rhodes, Saint Denis, or Blackwater**.
1. **Toggle Seller Mode**: Type `/sellweed` in your chat box.
2. **Wait for Buyers**: Civilian NPCs will approach you one-by-one.
3. **Negotiate**:
   - They will make an offer.
   - **Lowballers**: ~30% of market value (40% chance).
   - **Normal**: Market value (50% chance).
   - **Highballers**: ~150% of market value (10% chance).
4. **Risk**: There is a **50% chance** a witness will call the law!
5. **Auto-Stop**: If you run out of weed or step outside town boundaries, selling stops automatically.

### 🚬 Smoking Features
Enjoy your own supply with immersive effects. **Requires Matches**.
- **Joints**:
  - Craft with `Trimmed Bud` + `Rolling Paper` from inventory.
  - Effect: Restores Health & Stamina. Screen blur effects.
  - **Animations**: Unique enter/exit animations, changing stances (Male only).
- **Pipes**:
  - Buy a **Smoking Pipe**.
  - **Load It**: Use the pipe item in inventory to auto-load `Trimmed Bud`.
  - **Capacity**: 10 Puffs per load.
  - Drop key (Default B) to stop smoking.

### 👮 Legal Limits
- **Illegal Farming**: Growing more than **20 plants** triggers a major police alert ("Large Illegal Farm").
- **Selling**: Selling on the street risks police attention if witnessed.

## Credits
**Weed Plant Props**: [DerHobbs](https://github.com/DerHobbs/Weed_plant_prop_for_RedM)
