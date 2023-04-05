from replace_function import replace_in_file

lab2_bug_original_str = "'S': tenantContext.tenant_id"

lab2_bug_update_str = "'S': 'tenant-a'"

replace_in_file(lab2_bug_original_str, lab2_bug_update_str,
                "../../lib/product/app/code/app.py")
