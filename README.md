# skooter-infra
Bolt on infrastructure parts for the Skooter Base

## 🧱 PHASE 1: Create Your Thin Repo from the Template

This is **one-time setup** to take your `skooter-infra` GitHub template and use it to seed your `skooter-example-org-infra` thin repo in Gitea.

---

### ✅ Step 1: Clone the GitHub template repo (run this on your Mac)

```bash
git clone git@github.com:matthewsalla/skooter-infra.git
cd skooter-infra
```

This gives you a clean copy of the latest template.

---

### ✅ Step 2: Rename `origin` to `upstream` (still inside the template folder)

```bash
git remote rename origin upstream
```

This tells Git: "GitHub is the upstream template now."

---

### ✅ Step 3: Point to your **Gitea thin repo** as the new `origin`

```bash
git remote add origin git@git.github.com:exampleorg/skooter-example-org-infra.git
```

Now your Git remotes look like this:

```bash
git remote -v
```

```
origin    git@git.github.com:exampleorg/skooter-example-org-infra.git
upstream  git@github.com:matthewsalla/skooter-infra.git
```

---

### ✅ Step 4: Push the repo to Gitea to initialize your thin repo

```bash
git push -u origin main
```

Now your Gitea thin repo (`skooter-example-org-infra`) has all the files from the GitHub template.

You can now **delete this local clone** (or just move on).

---

## 🔁 PHASE 2: Future Updates (when you want to pull updates from the template)

Let’s say in a few days or weeks, you make updates to your GitHub `skooter-infra` repo and want those updates in your **thin repo** (in Gitea).

### ✅ Step 1: Clone your thin repo (from Gitea)

```bash
git clone git@git.github.com:exampleorg/skooter-example-org-infra.git
cd skooter-example-org-infra
```

---

### ✅ Step 2: Add the GitHub template as `upstream`

```bash
git remote add upstream git@github.com:matthewsalla/skooter-infra.git
git fetch upstream
```

---

### ✅ Step 3: Pull in updates from upstream

```bash
git merge upstream/main
```

Resolve any conflicts (if any), test, then:

```bash
git push origin main
```

---

## ✅ Visual Summary

```text
[GitHub: skooter-infra]       ← (template)
       ↓
  git clone + push to →
       ↓
[Gitea: skooter-example-org-infra] ← (thin repo you work in daily)

Then later:

[Gitea thin repo]
   ↑
 git fetch upstream
 git merge upstream/main  ← (bring in new template changes)
```
