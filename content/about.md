+++
title = "About"
description = "About Me"
showDate = false
slug = "about"
+++

I am Arsen Musayelyan, also sometimes known as Arsen6331 or Heisenbug online. I am <span id="age">Loading...</span> years old, and I am a Software Engineer.

I am very passionate about software development, automation, microcontrollers, and open-source projects in general. I also love learning new things in those fields and trying them out to see if I can make anything I find interesting.

In my free time, I work on anything from DIY microcontroller gadgets to smartwatch companion apps to contributions to open-source projects.

I've contributed to several projects, such as the [TinyGo compiler](https://github.com/tinygo-org/tinygo), [TinyGo's Drivers](https://github.com/tinygo-org/drivers), and [InfiniTime](https://github.com/infiniTimeOrg/InfiniTime).

I also have many of my own open-source projects, some of which are listed on the [projects page](/projects) of this site, and the rest can be found on my [Gitea](https://gitea.arsenm.dev/Arsen6331) or mirrored to my [GitHub](https://github.com/Arsen6331).

Online Profiles:

- [Gitea](https://gitea.arsenm.dev/Arsen6331)
- [GitHub](https://github.com/Arsen6331)
- [LinkedIn](https://www.linkedin.com/in/arsen-musayelyan-9a850a1ab/)

<script>
    birthday = new Date("April 24, 2005");
    now = new Date();
    age = now.getFullYear() - birthday.getFullYear();
    if (now.getMonth() < birthday.getMonth()) {
        age--;
    } else if (now.getMonth() == birthday.getMonth() && now.getDate() < birthday.getDate()) {
        age--;
    }
    document.getElementById("age").innerHTML = age;
</script>