# USER.md — Phone Testing Guide (Moto G Stylus 5G - 2024)

This guide explains in plain, simple steps how to get your **Moto G Stylus 5G (2024)** ready, connect it to this computer, and test **SupplyCloset**.

Once you do the one-time setup in **Step 1**, the AI agent can automatically build and push app updates straight onto your phone whenever it is plugged in.

---

## Step 1: On Your Phone (Before Plugging In the USB Cable)

You only have to do this **once** on your Moto G Stylus 5G (2024):

| # | Action on Your Phone | Where to Tap |
| :---: | :--- | :--- |
| **1** | **Open Settings** | Swipe up from the home screen and tap the **Settings** (gear) icon. |
| **2** | **Go to About Phone** | Scroll all the way to the bottom and tap **About phone**. |
| **3** | **Find Build Number** | Scroll to the bottom of *About phone* until you see **Build number**. |
| **4** | **Tap Build Number 7 Times** | Tap **Build number** 7 times fast. Enter your phone PIN/pattern when asked. It will say: *"You are now a developer!"* |
| **5** | **Go to Developer Options** | Tap the **Back** arrow once → tap **System** → tap **Developer options**. |
| **6** | **Turn On USB Debugging** | Scroll down to the *Debugging* section, flip **USB debugging** to **ON**, and tap **OK** on the popup. |
| **7** | *(Recommended)* **Turn On "Stay Awake"** | Near the top of *Developer options*, flip **Stay awake** to **ON** (keeps your screen from locking while plugged into USB so the AI agent can push updates anytime). |

---

## Step 2: Plug Your Phone Into the Computer

| # | Action | What You'll See |
| :---: | :--- | :--- |
| **1** | **Plug in the USB-C cable** | Connect your Moto G Stylus 5G (2024) to this Windows computer. Make sure your phone screen is **unlocked**. |
| **2** | **Approve the Popup on Your Phone** | A box will pop up on your phone asking: **"Allow USB debugging?"** |
| **3** | **Check "Always allow" & Tap Allow** | ✅ Check the box **"Always allow from this computer"**, then tap **Allow**. |

*(Troubleshooting tip: If no popup appears, swipe down from the top of your phone screen, tap the **"Charging this device via USB"** notification, and change it to **"File transfer"**.)*

---

## Step 3: Let the AI Agent Push the App to Your Phone

Once your phone is plugged in and unlocked:

1. Just tell the AI in chat:
   > **"My phone is plugged in—push the app to my phone."**
2. The AI agent will automatically:
   - Detect your **Moto G Stylus 5G (2024)**
   - Compile the latest **SupplyCloset** code
   - Install and launch the app right on your phone screen!
3. Once it is installed, you can even **unplug the USB cable** and walk into another room—the app stays installed on your phone.

---

## Step 4: How to Test & Map a Room on Your Phone

### Part A — Tag Supplies in SupplyCloset (5–10 minutes)

1. **Sign In:** Open **SupplyCloset** on your phone and tap **Sign in with Google**.
2. **Set Your Hospital & Unit:** Go to the **Profile** tab (bottom right) and pick a Facility and Unit so the app knows where to save your room data.
3. **Tag Items on a Shelf:**
   - Tap the **Tag** tab (or **Tag a Supply** button).
   - **Step 1 (Identify):** Tap any item from the **Quick-Tap Common Supplies** list (or type any item name in the search box and tap **Continue**).
   - **Step 2 (Locate):** Enter the **Shelf** (like `A`, `B`, or `C`) and **Bin** number (like `1`, `2`, `3`) and tap **Continue**.
   - **Step 3 (Confirm):** Tap **Tag Supply**. You'll earn **+10 XP** for each new item!
4. **Test Finding & Checklists:**
   - Tap the **Procedures** tab, pick a procedure (like *IV Start* or *Foley Catheter*), and tap **Find in Supply Room** to see your tagged shelf & bin locations.
   - Tap an item to confirm you found it (**+5 XP**) or report it missing.

---

### Part B — Capture a 3D Room Scan for "God's Eye View" (3–5 minutes)

To capture the 3D Gaussian Splat / 3D room model that we will load into the **"God's Eye View"** viewer:

1. Open the **Google Play Store** on your Moto G Stylus 5G and install **Scaniverse** (free app by Niantic).
2. Open **Scaniverse** → tap **+ New Scan** → choose **Splat** (or **Mesh**).
3. Stand at the doorway of your test room (or in front of a storage rack/pantry) and walk slowly side-to-side, pointing the camera at the shelves from a few angles for 2–3 minutes.
4. Tap **Done** → let it process on your phone → tap **Share / Export** → export as **`.ply` / `.splat`** (or **`.glb`**).
5. When you plug your phone back into the computer (or send the file to the computer), drop the file in this project folder and tell the AI:
   > **"Here is my room scan—hook it up to the God's Eye View viewer."**
