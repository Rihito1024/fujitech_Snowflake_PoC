-- 建物ディメンション（所在地・階数・所有者・施工会社等）
select
    building_id,
    building_name,
    building_control_number,
    number_of_floors,
    total_number_units,
    address_state,
    address_street,
    address_city,
    address_postal_code,
    address_state_code,
    address_country_code,
    latitude,
    longitude,
    building_owner_name,
    design_office_name,
    general_contractor_name,
    branch_in_charge,
    responsible_area,
    newly_established_former_construction

from {{ ref('stg_building') }}
