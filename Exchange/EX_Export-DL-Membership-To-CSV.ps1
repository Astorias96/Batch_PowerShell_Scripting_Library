﻿Get-DistributionGroup | %{$dlname = $_.Name; Get-DistributionGroupMember $dlname | select Identity,DisplayName,PrimarySMTPAddress | Export-CSV -path "$dlname.csv" -NoTypeInformation}