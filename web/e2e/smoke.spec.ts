import { expect, test, type APIRequestContext } from "@playwright/test";

async function registerAndLogin(request: APIRequestContext): Promise<string> {
  const suffix = Date.now();
  const email = `e2e-${suffix}@example.com`;
  const registered = await request.post("/auth/register", {
    data: { username: `e2e-${suffix}`, email, password: "secret123" },
  });
  expect(registered.ok()).toBeTruthy();
  const login = await request.post("/auth/login", {
    form: { username: email, password: "secret123" },
  });
  expect(login.ok()).toBeTruthy();
  return (await login.json()).access_token as string;
}

test("login, dashboard, settings and member creation/removal", async ({ page, request }) => {
  const token = await registerAndLogin(request);
  const memberName = `e2e-member-${Date.now()}`;
  await page.goto(`/?e2e_token=${token}`);
  await expect(page.getByRole("link", { name: /总览控制台/ })).toBeVisible({ timeout: 20_000 });

  await page.getByRole("link", { name: /系统设置/ }).click();
  await expect(page.getByText("租户", { exact: true })).toBeVisible();

  await page.getByText("成员", { exact: true }).click();
  await page.getByPlaceholder("用户名", { exact: true }).fill(memberName);
  await page.getByPlaceholder("邮箱", { exact: true }).fill(`${memberName}@example.com`);
  await page.getByPlaceholder("初始密码", { exact: true }).fill("secret123");
  await page.getByRole("button", { name: "添加成员" }).click();
  await expect(page.getByText(memberName, { exact: true })).toBeVisible();

  await page.locator(`button[aria-label="移除 ${memberName}"]`).click();
  await expect(page.getByText(memberName, { exact: true })).toHaveCount(0);

  await page.getByText("审计日志", { exact: true }).click();
  await expect(page.getByText("添加成员", { exact: true }).last()).toBeVisible();
  await expect(page.getByText("移除成员", { exact: true }).last()).toBeVisible();
  await expect(page.getByText("导出 CSV", { exact: true })).toBeVisible();
  await expect(page.getByText("归档", { exact: true })).toBeVisible();
});

test("create strategy and submit backtest", async ({ page, request }) => {
  const token = await registerAndLogin(request);
  await page.goto(`/?e2e_token=${token}`);
  await page.getByRole("link", { name: /策略工作台/ }).click();
  await page.getByRole("button", { name: "新建策略" }).click();
  await page.getByPlaceholder("策略名称").fill("E2E Strategy");
  await page.getByRole("button", { name: "创建", exact: true }).click();
  await expect(page.getByText("E2E Strategy", { exact: true })).toBeVisible();
  await page.getByText("E2E Strategy", { exact: true }).click();
  await page.getByText("回测", { exact: true }).first().click();
  await page.getByRole("button", { name: "启动回测" }).click();
  await expect(page.getByText("回测已提交", { exact: false })).toBeVisible();
});

test("accept invite and login as the new user", async ({ browser, request }) => {
  const token = await registerAndLogin(request);
  const suffix = Date.now();
  const invite = await request.post("/auth/invites", {
    headers: { Authorization: `Bearer ${token}` },
    data: { email: `invite-${suffix}@example.com`, role: "viewer" },
  });
  expect(invite.ok()).toBeTruthy();
  const inviteToken = (await invite.json()).token as string;

  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(`/?invite_token=${inviteToken}`);
  await page.locator("#invite-username").fill(`invitee-${suffix}`);
  await page.locator("#invite-password").fill("secret123");
  await page.getByRole("button", { name: "接受邀请" }).click();
  await expect(page.getByText("账号已创建", { exact: false })).toBeVisible();

  await page.getByRole("button", { name: "去登录" }).click();
  await page.getByLabel("用户名").fill(`invite-${suffix}@example.com`);
  await page.getByLabel("密码").fill("secret123");
  await page.getByRole("button", { name: "登录" }).click();
  await expect(page.getByRole("link", { name: /总览控制台/ })).toBeVisible({ timeout: 20_000 });
  await context.close();
});
