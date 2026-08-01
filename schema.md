## Table `users`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `fname` | `text` |  |
| `lname` | `text` |  |
| `role` | `user_role` |  |
| `email` | `text` |  Unique |
| `contactnum` | `text` |  Nullable |

## Table `primary_category`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `type` | `text` |  |

## Table `subcategory`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `p_category` | `uuid` |  |
| `type` | `text` |  |

## Table `units`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `abbr_name` | `text` |  |
| `name` | `text` |  |

## Table `item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `name` | `text` |  |
| `p_category` | `uuid` |  |
| `s_category` | `uuid` |  Nullable |
| `purchase_unit` | `uuid` |  |
| `package_unit` | `uuid` |  Nullable |
| `package_quantity` | `float8` |  Nullable |
| `dispense_unit` | `uuid` |  Nullable |
| `total_purchase_stocks` | `float8` |  |
| `total_package_stocks` | `float8` |  Nullable |

## Table `pet`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `name` | `text` |  |
| `species` | `pet_species` |  |
| `breed` | `text` |  Nullable |
| `gender` | `pet_gender` |  |
| `spayed_neutered` | `bool` |  |
| `status` | `pet_status` |  |

## Table `supplier`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `name` | `text` |  |
| `contactnum` | `text` |  Nullable |
| `contacttel` | `text` |  Nullable |
| `address` | `text` |  Nullable |

## Table `purchase`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `suppid` | `uuid` |  |
| `recordedby` | `uuid` |  |
| `recordeddate` | `timestamptz` |  |
| `receivedby` | `text` |  Nullable |
| `receiveddate` | `timestamptz` |  |

## Table `purchase_item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `purchaseid` | `uuid` | Primary |
| `itemid` | `uuid` | Primary |
| `qty` | `float8` |  |
| `purchase_unit_cost` | `numeric` |  |

## Table `treatment`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `name` | `text` |  |
| `petid` | `uuid` |  |
| `recordedby` | `uuid` |  |
| `recordeddate` | `timestamptz` |  |
| `notes` | `text` |  Nullable |

## Table `treatment_item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `treatid` | `uuid` |  |
| `itemid` | `uuid` |  |
| `dispensed_qty` | `float8` |  |
| `dispense_unit` | `uuid` |  |
| `consumeddate` | `timestamptz` |  |
| `givenby` | `text` |  Nullable |
| `recordeddate` | `timestamptz` |  |
| `recordedby` | `uuid` |  |
| `id` | `uuid` | Primary |

## Table `submission`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `donorid` | `uuid` |  |
| `updatedby` | `uuid` |  Nullable |
| `status` | `submission_status` |  |
| `drop_off_sched` | `timestamptz` |  Nullable |
| `datesubmitted` | `timestamptz` |  |
| `proof_img` | `text` |  Nullable |
| `notes` | `text` |  Nullable |
| `date_received` | `timestamptz` |  Nullable |

## Table `donation`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `donorid` | `uuid` |  Nullable |
| `subid` | `uuid` |  Nullable |
| `receivedby` | `text` |  Nullable |
| `receiveddate` | `timestamptz` |  |
| `recordedby` | `uuid` |  |
| `recordeddate` | `timestamptz` |  |
| `type` | `donation_type` |  |
| `donor_name` | `text` |  Nullable |

## Table `donation_item`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `dntid` | `uuid` | Primary |
| `itemid` | `uuid` | Primary |
| `qty` | `float8` |  |

## Table `stock_out`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `itemid` | `uuid` |  |
| `qty` | `float8` |  |
| `reason` | `stock_out_reason` |  |
| `recordeddate` | `timestamptz` |  |
| `recordedby` | `uuid` |  |

## Custom Types / Enums

### `user_role`

`manager` | `staff` | `donor`

### `pet_species`

`dog` | `cat`

### `pet_gender`

`male` | `female`

### `pet_status`

`available` | `adopted` | `under_treatment`

### `submission_status`

`pending` | `approved` | `rejected` | `received` | `stocked`

### `stock_out_reason`

`waste` | `expired` | `adjustment`

### `donation_type`

`walk_in` | `drop_off`

## RLS Policies

### `users`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `primary_category`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `subcategory`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `units`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `item`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `pet`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `supplier`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `purchase`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `purchase_item`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `treatment`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `treatment_item`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `submission`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `donation`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `donation_item`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

### `stock_out`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `authenticated read` | SELECT | authenticated | PERMISSIVE | `true` | — |
| `authenticated insert` | INSERT | authenticated | PERMISSIVE | — | `true` |
| `authenticated update` | UPDATE | authenticated | PERMISSIVE | `true` | `true` |
| `authenticated delete` | DELETE | authenticated | PERMISSIVE | `true` | — |

