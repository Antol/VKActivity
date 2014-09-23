VKActivity
==========

Remake of this repository https://github.com/denivip/VKActivity . UIAvtivity for share to vk.com

Install
-------

pod 'VKActivity'

Use
---

1) Create standalone app on this page https://vk.com/editapp?act=create . (Doc: https://vk.com/dev/standalone)

2) Fill App Id for iOS. 

3) Copy Application ID.

4) In AppDelegate (or wherever you want) add this 
```
    [VKSdk initializeWithDelegate:nil andAppId:<#VK_CLIENT_ID#>];
```
,where <#VK_CLIENT_ID#> your copied Application ID

5) use VKActivity 
```
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[title, url, image]
                                                                             applicationActivities:@[[[VKActivity alloc] initWithParent:self]]];
```

6) Profit
