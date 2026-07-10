## Table `users`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `userid` | `uuid` | Primary |
| `userfname` | `text` |  |
| `userlname` | `text` |  |
| `role` | `user_role` |  |
| `email` | `text` |  Unique |
| `contactnum` | `text` |  Nullable |

## Table `supplier`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `suppid` | `uuid` | Primary |
| `suppname` | `text` |  |
| `contactnum` | `text` |  Nullable |
| `address` | `text` |  Nullable |

## Table `item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `itemid` | `uuid` | Primary |
| `name` | `text` |  |
| `category` | `text` |  |
| `uom` | `text` |  |
| `currentstock` | `float4` |  |

## Table `pet`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `petid` | `uuid` | Primary |
| `petname` | `text` |  |
| `species` | `pet_species` |  |
| `breed` | `text` |  Nullable |
| `gender` | `pet_gender` |  |
| `spayed_neutered` | `bool` |  Nullable |
| `status` | `pet_status` |  Nullable |

## Table `submission`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `subid` | `uuid` | Primary |
| `donorid` | `uuid` |  |
| `revby` | `uuid` |  Nullable |
| `status` | `sub_status` |  Nullable |
| `scheddate` | `timestamptz` |  Nullable |
| `datesub` | `timestamptz` |  Nullable |
| `proofimg` | `text` |  Nullable |

## Table `donation`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `donid` | `uuid` | Primary |
| `subid` | `uuid` |  Nullable |
| `donorid` | `uuid` |  |
| `rcvdon` | `timestamptz` |  |
| `rcvdby` | `uuid` |  |

## Table `purchase_trans`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `purid` | `uuid` | Primary |
| `suppid` | `uuid` |  |
| `userid` | `uuid` |  |
| `rcvdon` | `timestamptz` |  Nullable |

## Table `treatment`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `treatid` | `uuid` | Primary |
| `petid` | `uuid` |  |
| `name` | `text` |  |
| `notes` | `text` |  Nullable |

## Table `donation_item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `donid` | `uuid` | Primary |
| `itemid` | `uuid` | Primary |
| `qty` | `int4` |  |

## Table `order_item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `orderid` | `uuid` | Primary |
| `itemid` | `uuid` | Primary |
| `qty` | `int4` |  |
| `unitcost` | `numeric` |  |

## Table `treatment_item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `treatid` | `uuid` | Primary |
| `itemid` | `uuid` | Primary |
| `qtyused` | `float4` |  |
| `givenon` | `timestamptz` |  |
| `givenby` | `text` |  |
| `userid` | `uuid` |  |
| `recdate` | `timestamptz` |  |
| `uom` | `text` |  |

