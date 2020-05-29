application = 
{
	content = 
	{ 
		-- The aspect ratio of the device we're running on is display.pixelHeight/display.pixelWidth.  (We can't use display.contentHeight/display.contentWidth as the aspect ratio, because it's the content area that we're now about to define!  Also, we can't save the aspect to a variable, because config.lua is just a table.  So we'll have to repeat it a few times.)
 
		-- This example uses a base size of 320x480, which is an aspect ratio of 1.5.  One could modify this example to use other base sizes by simply replacing the 320, 480, and 1.5s with some other values
 
		-- The content width will be 320, our base value, *unless* the device we're running on has a squatter aspect ratio, i.e., an aspect ratio *below* 1.5.  In that case, we'll keep the height constant at 480, and we'll make the width wider than 320 so that the aspect ratio is the squat ratio.  What should the width be?  We'll take 320 and multiply it by the ratio of our assumed aspect ratio (1.5) and the device's actual aspect ratio
		width = 320 * (display.pixelHeight/display.pixelWidth>1.5 and 1 or 1.5/(display.pixelHeight/display.pixelWidth)),
 
		-- The content height will be 480, our base value, *unless* the device we're running on has a taller aspect ratio, i.e., an aspect ratio *above* 1.5.  In that case, we'll keep the width constant at 320, and we'll make the height taller than 480 so that the aspect ratio is the tall ratio.  What should the height be?  We'll take 480 and multiply it by the ratio of the device's actual aspect ratio and our assumed aspect ratio (1.5)
		height = 480 * (display.pixelHeight/display.pixelWidth<1.5 and 1 or (display.pixelHeight/display.pixelWidth)/1.5),
 
		-- We're using letterbox scaling
		scale = "letterbox",
 
		imageSuffix =
		{
			["@2x"] = 1.5,
			["@4x"] = 3.0,
		},
	},
	license =
    {
        google =
        {
			key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArXNqxAZL9uEs0fSTDADPumpm4aNz+07ZhOvgmWV8o8JP6HDzg+2LuT40qXFmyGOHtGrdgdAfJICjWeSPjpK7XUzMbspyDg8oX03LhUlGD2W/t2Ik9bur938eJHtCYgwAaiX0N5ut0ZfrgS7jdQbwyLrW7sqoPzs7hRWxLlm02aCHqNur9MGtuLETAME60neNVurEmvMVeTRZ5mP5TdWKIKd4+or/qUmOxIOrMi6nY5JgJ+3MXa0cohhOaPiozl1MkJUil5v1b+Zg60kb+KD1PU164IUxNYYHLzZ4bjKmgC0TKyM4qj2WgFy9m9qcZQyCLMd4G8aEo7G7Ixn/JG1ElwIDAQAB",
			policy = "serverManaged"
        },
    },
}