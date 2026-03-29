package main

import (
	"github.com/gofiber/fiber/v2"
	"log"
)

func main() {
	app := fiber.New(fiber.Config{
		DisableStartupMessage: true,
	})

	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"framework": "Go Fiber",
			"language":  "Go",
			"speed":     "Blazing Fast",
		})
	})

	log.Fatal(app.Listen(":3001"))
}
