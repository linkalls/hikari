package main

import (
	"github.com/gofiber/fiber/v2"
	"log"
)

func main() {
	app := fiber.New(fiber.Config{
		DisableStartupMessage: true,
	})

	// JSON エンドポイント（フレームワーク比較の基準）
	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"framework": "Go Fiber",
			"language":  "Go",
			"speed":     "Blazing Fast",
		})
	})

	// プレーンテキストエンドポイント（最小オーバーヘッド計測）
	app.Get("/text", func(c *fiber.Ctx) error {
		return c.SendString("Hello, World!")
	})

	// パスパラメータエンドポイント（ルーター性能計測）
	app.Get("/users/:id", func(c *fiber.Ctx) error {
		id := c.Params("id")
		return c.JSON(fiber.Map{
			"id":   id,
			"name": "User " + id,
		})
	})

	log.Fatal(app.Listen(":3001"))
}
