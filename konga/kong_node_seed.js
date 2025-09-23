module.exports = [
	{
		name: "kong-gateway",
		type: "default",
		kong_admin_url: "http://kong:8001",
		health_checks: true,
		health_check_details: true,
		kong_version: "3.4.x",
		active: true,
		created_at: new Date().toISOString(),
		updated_at: new Date().toISOString(),
	},
];
